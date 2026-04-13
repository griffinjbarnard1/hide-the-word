import CloudKit
import Foundation
import ScriptureMemory

@MainActor
protocol SocialServicing: AnyObject {
    var groups: [SharedPlanGroup] { get }
    var isLoading: Bool { get }
    var lastError: String? { get }
    var syncStateByGroupID: [String: SharedPlanSyncState] { get }

    func fetchGroups() async
    func createSharedPlan(
        planID: UUID,
        planTitle: String,
        planDuration: Int,
        planSystemImage: String,
        ownerName: String,
        ownerEnrollment: PlanEnrollment?,
        ownerStreak: Int
    ) async -> CKShare?
    func syncMyProgress(
        groupZoneID: CKRecordZone.ID,
        memberName: String,
        currentDay: Int,
        completedDays: Set<Int>,
        streak: Int
    ) async -> SharedPlanSyncResult
}

/// Thin social domain layer used by Together surfaces.
///
/// The current app only supports collaboration inside a shared plan.
/// This service isolates that behavior from UI code so we can later add
/// global social capabilities (for example, friend connections) without
/// threading CloudKit plan membership details throughout views.
@MainActor
@Observable
final class SocialService: SocialServicing {
    static let shared = SocialService(manager: .shared)

    private let manager: SharedPlanManager

    var groups: [SharedPlanGroup] = []
    var isLoading = false
    var lastError: String?
    var syncStateByGroupID: [String: SharedPlanSyncState] = [:]

    init(manager: SharedPlanManager) {
        self.manager = manager
        refreshSnapshot()
    }

    func fetchGroups() async {
        await manager.fetchGroups()
        refreshSnapshot()
    }

    func createSharedPlan(
        planID: UUID,
        planTitle: String,
        planDuration: Int,
        planSystemImage: String,
        ownerName: String,
        ownerEnrollment: PlanEnrollment?,
        ownerStreak: Int
    ) async -> CKShare? {
        let share = await manager.createSharedPlan(
            planID: planID,
            planTitle: planTitle,
            planDuration: planDuration,
            planSystemImage: planSystemImage,
            ownerName: ownerName,
            ownerEnrollment: ownerEnrollment,
            ownerStreak: ownerStreak
        )
        refreshSnapshot()
        return share
    }

    func syncMyProgress(
        groupZoneID: CKRecordZone.ID,
        memberName: String,
        currentDay: Int,
        completedDays: Set<Int>,
        streak: Int
    ) async -> SharedPlanSyncResult {
        let result = await manager.syncMyProgress(
            groupZoneID: groupZoneID,
            memberName: memberName,
            currentDay: currentDay,
            completedDays: completedDays,
            streak: streak
        )
        refreshSnapshot()
        return result
    }

    private func refreshSnapshot() {
        groups = manager.groups
        isLoading = manager.isLoading
        lastError = manager.lastError
        syncStateByGroupID = manager.syncStateByGroupID
    }
}
