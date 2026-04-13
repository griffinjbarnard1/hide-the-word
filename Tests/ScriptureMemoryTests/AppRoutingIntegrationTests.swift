import Foundation
import Testing
@testable import ScriptureMemory

struct AppRoutingIntegrationTests {
    @Test
    func routeBuilderAndURLComponentsRoundTrip() {
        let setID = BuiltInContent.faithSetID
        let url = AppRouteBuilder.url(for: .todaySession, setID: setID)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        #expect(url.scheme == "scripturememory")
        #expect(url.host == "session")
        #expect(url.path == "/today")
        #expect(components?.queryItems?.first(where: { $0.name == "setID" })?.value == setID.uuidString)
    }

    @Test
    func routeRawValuesRemainStableForAppAndWidgets() {
        #expect(AppRoute.todaySession.rawValue == "session/today")
        #expect(AppRoute.verseSets.rawValue == "sets")
        #expect(AppRoute.library.rawValue == "library")
        #expect(AppRoute.journey.rawValue == "journey")
        #expect(AppRoute.settings.rawValue == "settings")
        #expect(AppRoute.plans.rawValue == "plans")
    }
}
