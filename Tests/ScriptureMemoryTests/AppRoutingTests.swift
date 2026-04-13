import Foundation
import Testing
@testable import ScriptureMemory

struct AppRoutingTests {
    @Test
    func routeFromURLHandlesHostAndPathVariants() {
        #expect(AppRouteBuilder.route(from: URL(string: "scripturememory://session/today")!) == .todaySession)
        #expect(AppRouteBuilder.route(from: URL(string: "scripturememory:///session/today")!) == .todaySession)
        #expect(AppRouteBuilder.route(from: URL(string: "scripturememory://plans?source=widget")!) == .plans)
    }

    @Test
    func routeFromURLRejectsUnknownScheme() {
        #expect(AppRouteBuilder.route(from: URL(string: "https://example.com/plans")!) == nil)
    }
}
