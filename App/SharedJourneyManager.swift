import CloudKit
import Foundation
import ScriptureMemory

// MARK: - Models

struct SharedPlanGroup: Identifiable, Codable, Hashable, Sendable {
    let id: String // CKRecordZone name
    let zoneOwnerName: String
    let planID: UUID
    let planTitle: String
    let planDuration: Int
    let planSystemImage: String
    let createdAt: Date
    let ownerName: String
    let ownerMemberID: String?
    var members: [SharedPlanMember]
}

struct SharedPlanMember: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    var currentDay: Int
    var completedDays: Set<Int>
    var streak: Int
    var lastActiveAt: Date?
}

// MARK: - Manager

@MainActor
@Observable
final class SharedPlanManager {
    private let container: CKContainer
    private let privateDB: CKDatabase

    var groups: [SharedPlanGroup] = []
    var isLoading = false
    var lastError: String?

    static let containerID = "iCloud.com.griffinbarnard.ScriptureMemory"
    private static let groupRecordType = "SharedPlan"
    private static let memberRecordType = "PlanMember"

    struct ActionFeedback: Sendable {
        let success: Bool
        let message: String
    }

    init() {
        container = CKContainer(identifier: Self.containerID)
        privateDB = container.privateCloudDatabase
    }

    // MARK: - Stable Member ID

    func stableMemberID() async -> String {
        do {
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch {
            return CKCurrentUserDefaultName
        }
    }

    func isOwner(of group: SharedPlanGroup, currentMemberID: String?, currentDisplayName: String) -> Bool {
        if let currentMemberID {
            if let ownerMemberID = group.ownerMemberID {
                return ownerMemberID == currentMemberID
            }
            return group.members.contains(where: { $0.id == "member-\(currentMemberID)" && $0.displayName == group.ownerName })
        }
        return group.ownerName == currentDisplayName
    }

    // MARK: - Create Shared Plan

    func createSharedPlan(
        planID: UUID,
        planTitle: String,
        planDuration: Int,
        planSystemImage: String,
        ownerName: String,
        ownerEnrollment: PlanEnrollment?,
        ownerStreak: Int
    ) async -> CKShare? {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let memberID = await stableMemberID()
        let zoneID = CKRecordZone.ID(zoneName: "Plan-\(UUID().uuidString)", ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            try await privateDB.save(zone)

            let planRecord = CKRecord(recordType: Self.groupRecordType, recordID: CKRecord.ID(recordName: "plan", zoneID: zoneID))
            planRecord["planID"] = planID.uuidString
            planRecord["planTitle"] = planTitle
            planRecord["planDuration"] = planDuration
            planRecord["planSystemImage"] = planSystemImage
            planRecord["ownerName"] = ownerName
            planRecord["ownerMemberID"] = memberID
            planRecord["createdAt"] = Date.now

            try await privateDB.save(planRecord)

            // Save owner's current progress
            let memberRecord = CKRecord(recordType: Self.memberRecordType, recordID: CKRecord.ID(recordName: "member-\(memberID)", zoneID: zoneID))
            memberRecord["memberName"] = ownerName
            memberRecord["currentDay"] = ownerEnrollment?.currentDay ?? 1
            memberRecord["streak"] = ownerStreak
            memberRecord["lastActiveAt"] = Date.now
            if let enrollment = ownerEnrollment {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(Array(enrollment.completedDays)),
                   let json = String(data: data, encoding: .utf8) {
                    memberRecord["completedDaysJSON"] = json
                }
            }
            try await privateDB.save(memberRecord)

            // Create share
            let share = CKShare(rootRecord: planRecord)
            share[CKShare.SystemFieldKey.title] = "Join \(planTitle) on Hide the Word" as CKRecordValue
            share.publicPermission = .readWrite

            let op = CKModifyRecordsOperation(recordsToSave: [planRecord, share], recordIDsToDelete: nil)
            op.isAtomic = true
            op.qualityOfService = .userInitiated
            privateDB.add(op)

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success: cont.resume()
                    case .failure(let error): cont.resume(throwing: error)
                    }
                }
            } as Void

            await fetchGroups()
            return share
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Sync My Progress

    func syncMyProgress(
        groupZoneID: CKRecordZone.ID,
        memberName: String,
        currentDay: Int,
        completedDays: Set<Int>,
        streak: Int
    ) async {
        let memberID = await stableMemberID()
        let recordID = CKRecord.ID(recordName: "member-\(memberID)", zoneID: groupZoneID)

        do {
            let record: CKRecord
            do {
                // Try shared DB first (for plans shared with us), then private
                record = try await container.sharedCloudDatabase.record(for: recordID)
            } catch {
                do {
                    record = try await privateDB.record(for: recordID)
                } catch {
                    record = CKRecord(recordType: Self.memberRecordType, recordID: recordID)
                }
            }

            record["memberName"] = memberName
            record["currentDay"] = currentDay
            record["streak"] = streak
            record["lastActiveAt"] = Date.now

            let encoder = JSONEncoder()
            if let data = try? encoder.encode(Array(completedDays)),
               let json = String(data: data, encoding: .utf8) {
                record["completedDaysJSON"] = json
            }

            try await privateDB.save(record)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Fetch Groups

    func fetchGroups() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        var fetched: [SharedPlanGroup] = []

        do {
            let zones = try await privateDB.allRecordZones()
            let planZones = zones.filter { $0.zoneID.zoneName.hasPrefix("Plan-") }
            for zone in planZones {
                if let group = await fetchGroup(in: zone.zoneID, database: privateDB) {
                    fetched.append(group)
                }
            }

            let sharedDB = container.sharedCloudDatabase
            let sharedZones = try await sharedDB.allRecordZones()
            let sharedPlanZones = sharedZones.filter { $0.zoneID.zoneName.hasPrefix("Plan-") }
            for zone in sharedPlanZones {
                if let group = await fetchGroup(in: zone.zoneID, database: sharedDB) {
                    fetched.append(group)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }

        groups = fetched.sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchGroup(in zoneID: CKRecordZone.ID, database: CKDatabase) async -> SharedPlanGroup? {
        let planRecordID = CKRecord.ID(recordName: "plan", zoneID: zoneID)
        guard let planRecord = try? await database.record(for: planRecordID) else { return nil }

        let planID = (planRecord["planID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let planTitle = planRecord["planTitle"] as? String ?? "Plan"
        let planDuration = planRecord["planDuration"] as? Int ?? 0
        let planSystemImage = planRecord["planSystemImage"] as? String ?? "calendar"
        let ownerName = planRecord["ownerName"] as? String ?? "Unknown"
        let ownerMemberID = planRecord["ownerMemberID"] as? String
        let createdAt = planRecord["createdAt"] as? Date ?? .now

        let query = CKQuery(recordType: Self.memberRecordType, predicate: NSPredicate(value: true))
        var members: [SharedPlanMember] = []

        do {
            let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)
            let decoder = JSONDecoder()

            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                let name = record["memberName"] as? String ?? "Unknown"
                let currentDay = record["currentDay"] as? Int ?? 1
                let streak = record["streak"] as? Int ?? 0
                let lastActive = record["lastActiveAt"] as? Date

                var completedDays: Set<Int> = []
                if let json = record["completedDaysJSON"] as? String,
                   let data = json.data(using: .utf8),
                   let days = try? decoder.decode([Int].self, from: data) {
                    completedDays = Set(days)
                }

                members.append(SharedPlanMember(
                    id: record.recordID.recordName,
                    displayName: name,
                    currentDay: currentDay,
                    completedDays: completedDays,
                    streak: streak,
                    lastActiveAt: lastActive
                ))
            }
        } catch {
            // Zone might not have member records yet
        }

        return SharedPlanGroup(
            id: zoneID.zoneName,
            zoneOwnerName: zoneID.ownerName,
            planID: planID,
            planTitle: planTitle,
            planDuration: planDuration,
            planSystemImage: planSystemImage,
            createdAt: createdAt,
            ownerName: ownerName,
            ownerMemberID: ownerMemberID,
            members: members.sorted { $0.currentDay > $1.currentDay }
        )
    }

    // MARK: - Accept Share

    func acceptShare(_ metadata: CKShare.Metadata) async {
        do {
            try await container.accept(metadata)
            await fetchGroups()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Leave Group

    func leaveGroup(_ group: SharedPlanGroup, currentDisplayName: String) async -> ActionFeedback {
        let memberID = await stableMemberID()
        let isOwner = isOwner(of: group, currentMemberID: memberID, currentDisplayName: currentDisplayName)
        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: group.zoneOwnerName)
        let recordID = CKRecord.ID(recordName: "member-\(memberID)", zoneID: zoneID)
        let isPrivatelyOwnedZone = group.zoneOwnerName == CKCurrentUserDefaultName

        do {
            if isOwner && isPrivatelyOwnedZone {
                try await privateDB.deleteRecordZone(withID: zoneID)
                await fetchGroups()
                return ActionFeedback(success: true, message: "Sharing stopped. The group was archived for everyone.")
            }

            if isPrivatelyOwnedZone {
                try await privateDB.deleteRecord(withID: recordID)
                await fetchGroups()
                return ActionFeedback(success: true, message: "You left the shared plan.")
            }

            do {
                try await container.sharedCloudDatabase.deleteRecordZone(withID: zoneID)
                await fetchGroups()
                return ActionFeedback(success: true, message: "You left the shared plan.")
            } catch {
                try await container.sharedCloudDatabase.deleteRecord(withID: recordID)
            }
            await fetchGroups()
            return ActionFeedback(success: true, message: "You left the shared plan.")
        } catch {
            lastError = error.localizedDescription
            return ActionFeedback(success: false, message: "Couldn't complete that action right now. Please try again.")
        }
    }
}
