import Foundation
import WidgetKit

enum WidgetData {
    static let appGroupID = "group.com.griffinbarnard.ScriptureMemory"
    static let dueCountKey = "widget_due_count"
    static let nextReferenceKey = "widget_next_reference"
    static let collectionNameKey = "widget_collection_name"
    static let updatedAtKey = "widget_updated_at"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(dueCount: Int, nextReference: String?, collectionName: String) {
        write(
            dueCount: dueCount,
            nextReference: nextReference,
            collectionName: collectionName,
            defaults: defaults,
            now: Date.now,
            reload: { WidgetCenter.shared.reloadAllTimelines() }
        )
    }

    static func write(
        dueCount: Int,
        nextReference: String?,
        collectionName: String,
        defaults: UserDefaults?,
        now: Date,
        reload: () -> Void
    ) {
        guard let defaults else { return }
        defaults.set(dueCount, forKey: dueCountKey)
        defaults.set(nextReference, forKey: nextReferenceKey)
        defaults.set(collectionName, forKey: collectionNameKey)
        defaults.set(now.timeIntervalSince1970, forKey: updatedAtKey)
        reload()
    }
}
