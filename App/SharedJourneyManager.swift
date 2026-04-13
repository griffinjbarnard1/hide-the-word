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
    var profile: PublicProfile?
}

struct PublicProfile: Identifiable, Codable, Hashable, Sendable {
    static let maxDisplayNameLength = 32
    static let maxBioLength = 160
    static let maxFavoriteVerseLength = 80
    static let maxAvatarSeedLength = 24

    let id: String
    var displayName: String
    var bio: String
    var favoriteVerse: String
    var avatarSeed: String
    var updatedAt: Date

    init(
        id: String,
        displayName: String,
        bio: String = "",
        favoriteVerse: String = "",
        avatarSeed: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.displayName = Self.clean(displayName, max: Self.maxDisplayNameLength)
        self.bio = Self.clean(bio, max: Self.maxBioLength)
        self.favoriteVerse = Self.clean(favoriteVerse, max: Self.maxFavoriteVerseLength)
        self.avatarSeed = Self.clean(avatarSeed, max: Self.maxAvatarSeedLength)
        self.updatedAt = updatedAt
    }

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func clean(_ text: String, max: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(max))
    }
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

enum PublicProfilePersistenceStatus: Sendable, Equatable {
    case savedLocally
    case syncedToSharedPlans
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

    enum IdentityStatus: String, Sendable {
        case available
        case unavailable
        case restricted
    }

    struct IdentitySnapshot: Sendable {
        let status: IdentityStatus
        let resolvedIdentity: String?
    }
    private let container: CKContainer
    private let privateDB: CKDatabase

    var groups: [SharedPlanGroup] = []
    var isLoading = false
    var lastError: String?
    var syncStateByGroupID: [String: SharedPlanSyncState] = [:]
    var profilePersistenceStatus: PublicProfilePersistenceStatus = .savedLocally

    static let containerID = "iCloud.com.griffinbarnard.ScriptureMemory"
    static let shared = SharedPlanManager()
    private static let groupRecordType = "SharedPlan"
    /// Current storage model: one membership record per person per shared-plan zone.
    /// Extension point: keep this plan-local while introducing a separate `Connection`
    /// record type for global friend status in the future.
    private static let memberRecordType = "PlanMember"
    private static let profileRecordType = "PublicProfile"
    private static let localProfileDefaultsKey = "local-public-profile-v1"

    struct ActionFeedback: Sendable {
        let success: Bool
        let message: String
    }

    init() {
        container = CKContainer(identifier: Self.containerID)
        privateDB = container.privateCloudDatabase
        profilePersistenceStatus = .savedLocally
    }

    // MARK: - Identity

    func identitySnapshot() async -> IdentitySnapshot {
        let status = await identityStatus()
        guard status == .available else {
            return IdentitySnapshot(status: status, resolvedIdentity: nil)
        }

        do {
            let recordID = try await container.userRecordID()
            return IdentitySnapshot(status: status, resolvedIdentity: recordID.recordName)
        } catch {
            return IdentitySnapshot(status: status, resolvedIdentity: nil)
        }
    }

    func identityStatus() async -> IdentityStatus {
        do {
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available:
                return .available
            case .restricted:
                return .restricted
            case .noAccount, .temporarilyUnavailable, .couldNotDetermine:
                return .unavailable
            @unknown default:
                return .unavailable
            }
        } catch {
            return .unavailable
        }
    }

    func resolvedCloudKitIdentity() async -> String? {
        await identitySnapshot().resolvedIdentity
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

            let ownerProfile = PublicProfile(id: memberID, displayName: ownerName)
            let profileRecord = CKRecord(
                recordType: Self.profileRecordType,
                recordID: CKRecord.ID(recordName: "profile-\(memberID)", zoneID: zoneID)
            )
            write(profile: ownerProfile, to: profileRecord)
            try await privateDB.save(profileRecord)

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
        let targetDB = groupZoneID.ownerName == CKCurrentUserDefaultName ? privateDB : container.sharedCloudDatabase

        do {
            let record: CKRecord
            let targetDatabase: CKDatabase
            do {
                record = try await targetDB.record(for: recordID)
                targetDatabase = targetDB
            } catch {
                do {
                    let fallbackDB = targetDB === privateDB ? container.sharedCloudDatabase : privateDB
                    record = try await fallbackDB.record(for: recordID)
                    targetDatabase = fallbackDB
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

    func fetchMyProfile(defaultDisplayName: String) async -> PublicProfile {
        let memberID = await stableMemberID()
        if let localProfile = loadLocalProfile(), localProfile.id == memberID {
            return localProfile
        }

        if let remoteProfile = await fetchRemoteProfile(memberID: memberID, fallbackName: defaultDisplayName) {
            persistLocalProfile(remoteProfile)
            profilePersistenceStatus = groups.isEmpty ? .savedLocally : .syncedToSharedPlans
            return remoteProfile
        }

        let fallback = PublicProfile(id: memberID, displayName: defaultDisplayName)
        persistLocalProfile(fallback)
        profilePersistenceStatus = .savedLocally
        return fallback
    }

    func saveMyProfile(_ profile: PublicProfile) async -> Bool {
        let cleaned = PublicProfile(
            id: profile.id,
            displayName: profile.displayName,
            bio: profile.bio,
            favoriteVerse: profile.favoriteVerse,
            avatarSeed: profile.avatarSeed,
            updatedAt: .now
        )

        guard cleaned.isValid else {
            lastError = "Display name is required."
            return false
        }

        persistLocalProfile(cleaned)
        profilePersistenceStatus = .savedLocally
        lastError = nil

        if groups.isEmpty {
            return true
        }

        _ = await syncLocalProfileToSharedPlans(cleaned)
        await fetchGroups()
        return true
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

        if !groups.isEmpty, let localProfile = loadLocalProfile() {
            _ = await syncLocalProfileToSharedPlans(localProfile)
        }
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
        let ownerMemberID = planRecord["ownerMemberID"] as? String
        let createdAt = planRecord["createdAt"] as? Date ?? .now

        let query = CKQuery(recordType: Self.memberRecordType, predicate: NSPredicate(value: true))
        var members: [PlanMembership] = []
        var profilesByMemberID: [String: PublicProfile] = [:]

        do {
            let profileQuery = CKQuery(recordType: Self.profileRecordType, predicate: NSPredicate(value: true))
            let (profileResults, _) = try await database.records(matching: profileQuery, inZoneWith: zoneID)
            for (_, profileResult) in profileResults {
                guard let profileRecord = try? profileResult.get(),
                      let memberID = profileRecord["memberID"] as? String,
                      let profile = profile(from: profileRecord, fallbackName: "Unknown")
                else { continue }
                profilesByMemberID[memberID] = profile
            }
        } catch {}

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
                    lastActiveAt: lastActive,
                    profile: profilesByMemberID[record.recordID.recordName.replacingOccurrences(of: "member-", with: "")]
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

    private func profile(from record: CKRecord, fallbackName: String) -> PublicProfile? {
        guard let memberID = record["memberID"] as? String else { return nil }
        return PublicProfile(
            id: memberID,
            displayName: record["displayName"] as? String ?? fallbackName,
            bio: record["bio"] as? String ?? "",
            favoriteVerse: record["favoriteVerse"] as? String ?? "",
            avatarSeed: record["avatarSeed"] as? String ?? "",
            updatedAt: record["updatedAt"] as? Date ?? .now
        )
    }

    private func write(profile: PublicProfile, to record: CKRecord) {
        record["memberID"] = profile.id
        record["displayName"] = PublicProfile.clean(profile.displayName, max: PublicProfile.maxDisplayNameLength)
        record["bio"] = PublicProfile.clean(profile.bio, max: PublicProfile.maxBioLength)
        record["favoriteVerse"] = PublicProfile.clean(profile.favoriteVerse, max: PublicProfile.maxFavoriteVerseLength)
        record["avatarSeed"] = PublicProfile.clean(profile.avatarSeed, max: PublicProfile.maxAvatarSeedLength)
        record["updatedAt"] = Date.now
    }

    private func loadLocalProfile() -> PublicProfile? {
        guard let data = UserDefaults.standard.data(forKey: Self.localProfileDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(PublicProfile.self, from: data)
    }

    private func persistLocalProfile(_ profile: PublicProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.localProfileDefaultsKey)
    }

    private func fetchRemoteProfile(memberID: String, fallbackName: String) async -> PublicProfile? {
        for group in groups {
            let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: group.zoneOwnerName)
            let recordID = CKRecord.ID(recordName: "profile-\(memberID)", zoneID: zoneID)
            let databases: [CKDatabase] = group.zoneOwnerName == CKCurrentUserDefaultName
                ? [privateDB, container.sharedCloudDatabase]
                : [container.sharedCloudDatabase, privateDB]
            for database in databases {
                if let record = try? await database.record(for: recordID),
                   let profile = profile(from: record, fallbackName: fallbackName) {
                    return profile
                }
            }
        }
        return nil
    }

    @discardableResult
    private func syncLocalProfileToSharedPlans(_ profile: PublicProfile) async -> Bool {
        var didSyncAny = false
        for group in groups {
            let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: group.zoneOwnerName)
            let recordID = CKRecord.ID(recordName: "profile-\(profile.id)", zoneID: zoneID)
            let targetDB = group.zoneOwnerName == CKCurrentUserDefaultName ? privateDB : container.sharedCloudDatabase

            let record = (try? await targetDB.record(for: recordID)) ?? CKRecord(recordType: Self.profileRecordType, recordID: recordID)
            let existingUpdatedAt = record["updatedAt"] as? Date ?? .distantPast
            guard existingUpdatedAt <= profile.updatedAt else {
                didSyncAny = true
                continue
            }

            write(profile: profile, to: record)
            do {
                _ = try await targetDB.save(record)
                didSyncAny = true
            } catch {
                lastError = error.localizedDescription
            }
        }

        if didSyncAny {
            profilePersistenceStatus = .syncedToSharedPlans
        } else {
            profilePersistenceStatus = .savedLocally
        }
        return didSyncAny
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
