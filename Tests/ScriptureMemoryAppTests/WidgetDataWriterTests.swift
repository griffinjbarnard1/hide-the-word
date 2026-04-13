import Foundation
import ScriptureMemory
import Testing
@testable import ScriptureMemoryApp

struct WidgetDataWriterTests {
    @Test
    func writePersistsExpectedKeysAndPayload() {
        let suiteName = "WidgetDataWriterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let timestamp = Date(timeIntervalSince1970: 1_700_001_000)
        var reloadCount = 0

        WidgetData.write(
            dueCount: 6,
            nextReference: "John 3:16",
            collectionName: "Daily Verses",
            fallbackRoute: .plans,
            defaults: defaults,
            now: timestamp,
            reloadTimelines: { reloadCount += 1 }
        )

        #expect(defaults.integer(forKey: WidgetData.Keys.dueCount) == 6)
        #expect(defaults.string(forKey: WidgetData.Keys.nextReference) == "John 3:16")
        #expect(defaults.string(forKey: WidgetData.Keys.collectionName) == "Daily Verses")
        #expect(defaults.string(forKey: WidgetData.Keys.fallbackRoute) == AppRoute.plans.rawValue)
        #expect(defaults.double(forKey: WidgetData.Keys.updatedAt) == timestamp.timeIntervalSince1970)
        #expect(reloadCount == 1)
    }

    @Test
    func writeClearsFallbackRouteWhenNil() {
        let suiteName = "WidgetDataWriterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        WidgetData.write(
            dueCount: 1,
            nextReference: nil,
            collectionName: "Collection",
            fallbackRoute: nil,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 123),
            reloadTimelines: {}
        )

        #expect(defaults.string(forKey: WidgetData.Keys.fallbackRoute) == nil)
    }
}
