import Foundation
import WidgetKit

enum WidgetData {
    static let appGroupID = "group.com.griffinbarnard.ScriptureMemory"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(dueCount: Int, nextReference: String?, collectionName: String) {
        guard let defaults else { return }
        defaults.set(dueCount, forKey: "widget_due_count")
        defaults.set(nextReference, forKey: "widget_next_reference")
        defaults.set(collectionName, forKey: "widget_collection_name")
        defaults.set(Date.now.timeIntervalSince1970, forKey: "widget_updated_at")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
