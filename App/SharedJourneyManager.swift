import CloudKit
import Foundation
import ScriptureMemory

// MARK: - Models

struct SharedPlanGroup: Identifiable, Codable, Hashable, Sendable {
    let id: String // CKRecordZone name
    let planID: UUID
    let planTitle: String
    let planDuration: Int
    let planSystemImage: String
    let createdAt: Date
    let ownerName: String
    var members: [PlanMembership]
}

/// Membership scoped to a single shared plan zone.
///
/// This is intentionally plan-local data (not a global relationship model).
/// A person can appear with different progress/streak values in different plans.
struct PlanMembership: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    var currentDay: Int
    var completedDays: Set<Int>
    var streak: Int
    var lastActiveAt: Date?
}

/// Future global social relationship model.
///
/// Not yet persisted/read by `SharedPlanManager`; kept separate so friend-level
/// states can evolve independently from plan membership syncing.
struct Connection: Identifiable, Codable, Hashable, Sendable {
    enum Status: String, Codable, Hashable, Sendable {
        case invited
        case connected
        case blocked
    }

    let id: String
    let displayName: String
    let status: Status
}

enum SharedPlanSyncFailureReason: Sendable, Equatable {
    case cloudKitUnavailable(String)
    case saveFailed(String)
}

enum SharedPlanSyncResult: Sendable, Equatable {
    case success(syncedAt: Date)
    case failure(SharedPlanSyncFailureReason)
}

enum SharedPlanSyncState: Sendable, Equatable {
    case idle
    case syncing
    case success(Date)
    case failure(String)
}

// MARK: - Manager

@MainActor
@Observable
final class SharedPlanManager {
    /// Current collaboration constraints:
    /// - Social identity is derived from CloudKit user/member records inside each shared plan zone.
    /// - Membership and progress are scoped to plan zones; there is no cross-plan friend graph.
    ///
    /// Extension points for global social features:
    /// - Keep plan progress in `PlanMembership` records for deterministic plan sync semantics.
    /// - Introduce global friend state using `Connection` records/services, then join that data in UI.
    private let container: CKContainer
    private let privateDB: CKDatabase

    var groups: [SharedPlanGroup] = []
    var isLoading = false
    var lastError: String?
    var syncStateByGroupID: [String: SharedPlanSyncState] = [:]

    static let containerID = "iCloud.com.griffinbarnard.ScriptureMemory"
    static let shared = SharedPlanManager()
    private static let groupRecordType = "SharedPlan"
    /// Current storage model: one membership record per person per shared-plan zone.
    /// Extension point: keep this plan-local while introducing a separate `Connection`
    /// record type for global friend status in the future.
    private static let memberRecordType = "PlanMember"

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
    ) async -> SharedPlanSyncResult {
        // Conflict-safe merge rules (deterministic):
        // 1) Member identity is the record name `member-<stableMemberID>`, never display name.
        // 2) completedDays is treated as a set union across devices; never remove remote completions.
        // 3) currentDay/streak/lastActiveAt are monotonic: keep the max value, and newest timestamp.
        syncStateByGroupID[groupZoneID.zoneName] = .syncing
        let memberID = await stableMemberID()
        let recordID = CKRecord.ID(recordName: "member-\(memberID)", zoneID: groupZoneID)

        do {
            let record: CKRecord
            let targetDatabase: CKDatabase
            do {
                // Try shared DB first (for plans shared with us), then private
                record = try await container.sharedCloudDatabase.record(for: recordID)
                targetDatabase = container.sharedCloudDatabase
            } catch {
                do {
                    record = try await privateDB.record(for: recordID)
                    targetDatabase = privateDB
                } catch {
                    record = CKRecord(recordType: Self.memberRecordType, recordID: recordID)
                    do {
                        _ = try await container.sharedCloudDatabase.allRecordZones()
                        targetDatabase = container.sharedCloudDatabase
                    } catch {
                        targetDatabase = privateDB
                    }
                }
            }

            record["memberName"] = memberName
            let mergedCurrentDay = max(record["currentDay"] as? Int ?? 1, currentDay)
            let mergedStreak = max(record["streak"] as? Int ?? 0, streak)
            let now = Date.now
            let mergedLastActive = max(record["lastActiveAt"] as? Date ?? .distantPast, now)

            record["currentDay"] = mergedCurrentDay
            record["streak"] = mergedStreak
            record["lastActiveAt"] = mergedLastActive

            let encoder = JSONEncoder()
            var mergedCompletedDays = completedDays
            let decoder = JSONDecoder()
            if let existingJSON = record["completedDaysJSON"] as? String,
               let existingData = existingJSON.data(using: .utf8),
               let existingDays = try? decoder.decode([Int].self, from: existingData) {
                mergedCompletedDays.formUnion(existingDays)
            }
            if let data = try? encoder.encode(Array(mergedCompletedDays).sorted()),
               let json = String(data: data, encoding: .utf8) {
                record["completedDaysJSON"] = json
            }

            try await targetDatabase.save(record)
            syncStateByGroupID[groupZoneID.zoneName] = .success(now)
            return .success(syncedAt: now)
        } catch {
            let reason: SharedPlanSyncFailureReason = .saveFailed(error.localizedDescription)
            let message = error.localizedDescription
            lastError = message
            syncStateByGroupID[groupZoneID.zoneName] = .failure(message)
            return .failure(reason)
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
        // Conflict-safe merge rules (deterministic):
        // - Member rows are keyed by CloudKit record ID and sorted by currentDay descending.
        // - completedDaysJSON is decoded into a Set to remove duplicates from out-of-order writes.
        // - Missing/corrupt fields fall back to stable defaults so rendering is deterministic.
        let planRecordID = CKRecord.ID(recordName: "plan", zoneID: zoneID)
        guard let planRecord = try? await database.record(for: planRecordID) else { return nil }

        let planID = (planRecord["planID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let planTitle = planRecord["planTitle"] as? String ?? "Plan"
        let planDuration = planRecord["planDuration"] as? Int ?? 0
        let planSystemImage = planRecord["planSystemImage"] as? String ?? "calendar"
        let ownerName = planRecord["ownerName"] as? String ?? "Unknown"
        let createdAt = planRecord["createdAt"] as? Date ?? .now

        let query = CKQuery(recordType: Self.memberRecordType, predicate: NSPredicate(value: true))
        var members: [PlanMembership] = []

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

                members.append(PlanMembership(
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
            planID: planID,
            planTitle: planTitle,
            planDuration: planDuration,
            planSystemImage: planSystemImage,
            createdAt: createdAt,
            ownerName: ownerName,
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

    func leaveGroup(_ group: SharedPlanGroup, memberName: String) async {
        let memberID = await stableMemberID()
        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: CKCurrentUserDefaultName)
        let recordID = CKRecord.ID(recordName: "member-\(memberID)", zoneID: zoneID)

        do {
            try await privateDB.deleteRecord(withID: recordID)
            await fetchGroups()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
