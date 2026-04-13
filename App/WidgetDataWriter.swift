import Foundation
import ScriptureMemory
import WidgetKit

enum WidgetData {
    static let appGroupID = "group.com.griffinbarnard.ScriptureMemory"

    enum Keys {
        static let dueCount = "widget_due_count"
        static let nextReference = "widget_next_reference"
        static let collectionName = "widget_collection_name"
        static let fallbackRoute = "widget_fallback_route"
        static let updatedAt = "widget_updated_at"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(dueCount: Int, nextReference: String?, collectionName: String, fallbackRoute: AppRoute? = nil) {
        guard let defaults else { return }
        write(
            dueCount: dueCount,
            nextReference: nextReference,
            collectionName: collectionName,
            fallbackRoute: fallbackRoute,
            defaults: defaults,
            now: .now,
            reloadTimelines: { WidgetCenter.shared.reloadAllTimelines() }
        )
    }

    static func write(
        dueCount: Int,
        nextReference: String?,
        collectionName: String,
        fallbackRoute: AppRoute? = nil,
        defaults: UserDefaults,
        now: Date,
        reloadTimelines: () -> Void
    ) {
        defaults.set(dueCount, forKey: Keys.dueCount)
        defaults.set(nextReference, forKey: Keys.nextReference)
        defaults.set(collectionName, forKey: Keys.collectionName)
        defaults.set(fallbackRoute?.rawValue, forKey: Keys.fallbackRoute)
        defaults.set(now.timeIntervalSince1970, forKey: Keys.updatedAt)
        reloadTimelines()
    }
}
