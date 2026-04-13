import Foundation
import ScriptureMemory
import Testing
@testable import ScriptureMemoryApp

@MainActor
struct AppModelRoutingAndLifecycleTests {
    private func makeModel() throws -> AppModel {
        let store = try ReviewProgressStore(inMemory: true)
        return AppModel(progressStore: store)
    }

    @Test
    func handleIncomingURLRoutesToLibraryTab() throws {
        let model = try makeModel()

        model.handleIncomingURL(URL(string: "scripturememory://library")!)

        #expect(model.selectedTab == .library)
        #expect(model.activeRoute == nil)
    }

    @Test
    func handleIncomingURLEnrollsInSharedPlanAndOpensPlans() throws {
        let model = try makeModel()
        let planID = BuiltInPlans.psalm23.id.uuidString
        let url = URL(string: "scripturememory://share/plan-enroll?planID=\(planID)")!

        model.handleIncomingURL(url)

        #expect(model.activePlanEnrollment?.planID == BuiltInPlans.psalm23.id)
        #expect(model.activeRoute == .plans)
        #expect(model.selectedCollectionID == BuiltInContent.myVersesSetID)
    }

    @Test
    func planLifecycleUpdatesEnrollmentStateAsExpected() throws {
        let model = try makeModel()
        let plan = BuiltInPlans.psalm1

        model.enrollInPlan(plan)
        #expect(model.activePlanEnrollment?.planID == plan.id)
        #expect(model.activePlanEnrollment?.currentDay == 1)

        model.advancePlanDay()
        #expect(model.activePlanEnrollment?.currentDay == 2)
        #expect(model.activePlanEnrollment?.completedDays.contains(1) == true)

        model.leavePlan()
        #expect(model.activePlanEnrollment == nil)
    }

    @Test
    func lifecycleIntegrationCompletesPlanWhenAdvancedPastDuration() throws {
        let model = try makeModel()
        let plan = BuiltInPlans.psalm1

        model.enrollInPlan(plan)
        for _ in 0..<plan.duration {
            model.advancePlanDay()
        }

        #expect(model.isActivePlanComplete)
        #expect(model.activePlanEnrollment?.currentDay == plan.duration + 1)
    }
}
