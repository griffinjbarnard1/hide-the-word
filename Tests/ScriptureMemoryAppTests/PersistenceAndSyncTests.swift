import Foundation
import ScriptureMemory
import Testing
@testable import ScriptureMemoryApp

@MainActor
struct PersistenceAndSyncTests {
    @Test
    func reviewProgressStoreRoundTripsProgressAndCodablePayloads() throws {
        let store = try ReviewProgressStore(inMemory: true)
        let verseID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let nextReviewAt = Date(timeIntervalSince1970: 1_700_086_400)

        let progress = VerseProgress(
            verseID: verseID,
            reviewCount: 3,
            intervalDays: 2,
            lastReviewedAt: reviewedAt,
            nextReviewAt: nextReviewAt,
            lastRating: .medium
        )
        store.save(progress)

        let loaded = store.loadProgress()[verseID]
        #expect(loaded?.reviewCount == 3)
        #expect(loaded?.intervalDays == 2)
        #expect(loaded?.lastReviewedAt == reviewedAt)
        #expect(loaded?.nextReviewAt == nextReviewAt)
        #expect(loaded?.lastRating == .medium)

        let enrollment = PlanEnrollment(planID: BuiltInPlans.psalm23.id, startedAt: reviewedAt)
        store.saveCodableValue(enrollment, forKey: "active_plan_enrollment")
        let loadedEnrollment: PlanEnrollment? = store.loadCodableValue(forKey: "active_plan_enrollment")
        #expect(loadedEnrollment?.planID == enrollment.planID)
        #expect(loadedEnrollment?.currentDay == enrollment.currentDay)
    }

    @Test
    func sharedPlanMergePrefersMonotonicValuesAndUnionsDays() {
        let existing = SharedPlanProgressSnapshot(
            currentDay: 4,
            completedDays: [1, 2, 4],
            streak: 7,
            lastActiveAt: Date(timeIntervalSince1970: 1_700_000_010)
        )
        let now = Date(timeIntervalSince1970: 1_700_000_020)

        let merged = SharedPlanManager.mergeProgress(
            existing: existing,
            incomingCurrentDay: 3,
            incomingCompletedDays: [2, 3, 5],
            incomingStreak: 5,
            now: now
        )

        #expect(merged.currentDay == 4)
        #expect(merged.streak == 7)
        #expect(merged.lastActiveAt == now)
        #expect(merged.completedDays == [1, 2, 3, 4, 5])
    }

    @Test
    func sharedPlanMergeSupportsFirstWriteWithoutExistingRecord() {
        let now = Date(timeIntervalSince1970: 1_700_000_100)

        let merged = SharedPlanManager.mergeProgress(
            existing: nil,
            incomingCurrentDay: 2,
            incomingCompletedDays: [1],
            incomingStreak: 3,
            now: now
        )

        #expect(merged.currentDay == 2)
        #expect(merged.completedDays == [1])
        #expect(merged.streak == 3)
        #expect(merged.lastActiveAt == now)
    }
}
