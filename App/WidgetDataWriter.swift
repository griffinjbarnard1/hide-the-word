import Foundation
import ScriptureMemory
import WidgetKit

enum WidgetData {
    static let appGroupID = "group.com.griffinbarnard.ScriptureMemory"

    enum Keys {
        static let dueCount = "widget_due_count"
        static let nextReference = "widget_next_reference"
        static let nextPreviewMasked = "widget_next_preview_masked"
        static let nextPreviewBlotted = "widget_next_preview_blotted"
        static let collectionName = "widget_collection_name"
        static let fallbackRoute = "widget_fallback_route"
        static let updatedAt = "widget_updated_at"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(
        dueCount: Int,
        nextReference: String?,
        nextPreviewMasked: String? = nil,
        nextPreviewBlotted: String? = nil,
        collectionName: String,
        fallbackRoute: AppRoute? = nil
    ) {
        guard let defaults else { return }
        write(
            dueCount: dueCount,
            nextReference: nextReference,
            nextPreviewMasked: nextPreviewMasked,
            nextPreviewBlotted: nextPreviewBlotted,
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
        nextPreviewMasked: String? = nil,
        nextPreviewBlotted: String? = nil,
        collectionName: String,
        fallbackRoute: AppRoute? = nil,
        defaults: UserDefaults,
        now: Date,
        reloadTimelines: () -> Void
    ) {
        defaults.set(dueCount, forKey: Keys.dueCount)
        defaults.set(nextReference, forKey: Keys.nextReference)
        defaults.set(nextPreviewMasked, forKey: Keys.nextPreviewMasked)
        defaults.set(nextPreviewBlotted, forKey: Keys.nextPreviewBlotted)
        defaults.set(collectionName, forKey: Keys.collectionName)
        defaults.set(fallbackRoute?.rawValue, forKey: Keys.fallbackRoute)
        defaults.set(now.timeIntervalSince1970, forKey: Keys.updatedAt)
        reloadTimelines()
    }
}
