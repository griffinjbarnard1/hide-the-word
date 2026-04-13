import Foundation
import Testing
@testable import ScriptureMemoryApp

@MainActor
struct AppRoutingAndPlanLifecycleTests {
    @Test
    func incomingURLActionRoutesDeterministically() {
        let customPlanID = UUID()

        #expect(AppModel.incomingURLAction(for: URL(string: "scripturememory://session/today")!, customPlanIDs: []) == .startSession)
        #expect(AppModel.incomingURLAction(for: URL(string: "scripturememory://sets")!, customPlanIDs: []) == .openCollections)
        #expect(AppModel.incomingURLAction(for: URL(string: "scripturememory://library")!, customPlanIDs: []) == .openLibrary)
        #expect(AppModel.incomingURLAction(for: URL(string: "scripturememory://journey")!, customPlanIDs: []) == .openJourney)
        #expect(AppModel.incomingURLAction(for: URL(string: "scripturememory://settings")!, customPlanIDs: []) == .openSettings)
        #expect(
            AppModel.incomingURLAction(
                for: URL(string: "scripturememory://share/plan-enroll?planID=\(BuiltInPlans.psalm23.id.uuidString)")!,
                customPlanIDs: []
            ) == .enrollPlan(BuiltInPlans.psalm23.id)
        )
        #expect(
            AppModel.incomingURLAction(
                for: URL(string: "scripturememory://share/plan-enroll?planID=\(customPlanID.uuidString)")!,
                customPlanIDs: [customPlanID]
            ) == .enrollPlan(customPlanID)
        )
        #expect(AppModel.incomingURLAction(for: URL(string: "scripturememory://share/plan")!, customPlanIDs: []) == .handleSharedPlan)
        #expect(AppModel.incomingURLAction(for: URL(string: "scripturememory://unknown")!, customPlanIDs: []) == .ignore)
    }

    @Test
    func handleIncomingURLUpdatesNavigationState() {
        let store = ReviewProgressStore(inMemory: true)
        let appModel = AppModel(progressStore: store)

        appModel.handleIncomingURL(URL(string: "scripturememory://journey")!)
        #expect(appModel.selectedTab == .journey)

        appModel.handleIncomingURL(URL(string: "scripturememory://library")!)
        #expect(appModel.selectedTab == .library)

        appModel.handleIncomingURL(
            URL(string: "scripturememory://sets?setID=\(BuiltInContent.gospelSetID.uuidString)")!
        )
        #expect(appModel.selectedCollectionID == BuiltInContent.gospelSetID)
        #expect(appModel.activeRoute == .plans)
    }

    @Test
    func planLifecycleTransitionsExpectedState() {
        let store = ReviewProgressStore(inMemory: true)
        let appModel = AppModel(progressStore: store)
        let plan = BuiltInPlans.psalm23

        appModel.enrollInPlan(plan)
        #expect(appModel.activePlanEnrollment?.planID == plan.id)
        #expect(appModel.activePlanEnrollment?.currentDay == 1)
        #expect(appModel.activePlanEnrollment?.completedDays.isEmpty == true)

        appModel.advancePlanDay()
        #expect(appModel.activePlanEnrollment?.currentDay == 2)
        #expect(appModel.activePlanEnrollment?.completedDays.contains(1) == true)

        appModel.leavePlan()
        #expect(appModel.activePlanEnrollment == nil)
        let persisted: PlanEnrollment? = store.loadCodableValue(forKey: "active_plan_enrollment")
        #expect(persisted == nil)
    }
}

@MainActor
struct ReviewProgressStoreRoundTripTests {
    @Test
    func persistsAndLoadsProgressAndPreferences() {
        let store = ReviewProgressStore(inMemory: true)
        let verseID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let progress = VerseProgress(
            verseID: verseID,
            reviewCount: 4,
            intervalDays: 8,
            lastReviewedAt: now,
            nextReviewAt: now.addingTimeInterval(86_400),
            lastRating: .easy
        )

        store.save(progress)
        store.saveStringPreference("hello", forKey: "sample_key")
        store.saveDatePreference(now, forKey: "sample_date")

        let loaded = store.loadProgress()[verseID]
        #expect(loaded?.reviewCount == 4)
        #expect(loaded?.intervalDays == 8)
        #expect(loaded?.lastRating == .easy)
        #expect(store.loadStringPreference("sample_key") == "hello")
        #expect(store.loadDatePreference("sample_date") == now)
    }

    @Test
    func codableRoundTripAndReviewEventsRoundTrip() {
        let store = ReviewProgressStore(inMemory: true)
        let enrollment = PlanEnrollment(
            planID: BuiltInPlans.psalm23.id,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            currentDay: 3,
            completedDays: [1, 2],
            lastActiveAt: Date(timeIntervalSince1970: 1_700_086_400)
        )

        store.saveCodableValue(enrollment, forKey: "active_plan_enrollment")
        let loadedEnrollment: PlanEnrollment? = store.loadCodableValue(forKey: "active_plan_enrollment")
        #expect(loadedEnrollment == enrollment)

        let event = ReviewEvent(
            unitID: UUID(),
            unitReference: "Psalm 23:1",
            reviewedAt: Date(timeIntervalSince1970: 1_700_100_000),
            rating: .medium,
            kind: .review
        )
        store.saveReviewEvent(event)

        let loadedEvents = store.loadReviewEvents(limit: 5)
        #expect(loadedEvents.count == 1)
        #expect(loadedEvents.first?.unitReference == "Psalm 23:1")
        #expect(loadedEvents.first?.rating == .medium)
    }
}

struct SharedPlanMergeAndWidgetWriterTests {
    @Test
    func sharedPlanMergeUsesMonotonicAndUnionRules() {
        let now = Date(timeIntervalSince1970: 1_700_200_000)
        let existingJSON = "[1,3,4]"

        let merged = SharedPlanManager.mergeProgressState(
            existingCurrentDay: 3,
            existingStreak: 5,
            existingLastActiveAt: now.addingTimeInterval(-120),
            existingCompletedDaysJSON: existingJSON,
            incomingCurrentDay: 2,
            incomingCompletedDays: [2, 3],
            incomingStreak: 4,
            now: now
        )

        #expect(merged.currentDay == 3)
        #expect(merged.streak == 5)
        #expect(merged.lastActiveAt == now)
        #expect(merged.completedDays == [1, 2, 3, 4])
    }

    @Test
    func widgetWriterUpdatesExpectedKeysAndPayload() {
        let suiteName = "WidgetDataTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        var didReload = false
        let now = Date(timeIntervalSince1970: 1_700_300_000)
        WidgetData.write(
            dueCount: 7,
            nextReference: "John 3:16",
            collectionName: "My Verses",
            defaults: defaults,
            now: now,
            reload: { didReload = true }
        )

        #expect(defaults.integer(forKey: WidgetData.dueCountKey) == 7)
        #expect(defaults.string(forKey: WidgetData.nextReferenceKey) == "John 3:16")
        #expect(defaults.string(forKey: WidgetData.collectionNameKey) == "My Verses")
        #expect(defaults.double(forKey: WidgetData.updatedAtKey) == now.timeIntervalSince1970)
        #expect(didReload)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
