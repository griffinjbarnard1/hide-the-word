import WidgetKit
import SwiftUI

struct WidgetEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let nextReference: String?
    let collectionName: String
    let fallbackRoute: String?

    var deepLinkURL: URL? {
        let route = dueCount > 0 ? "session/today" : (fallbackRoute ?? "session/today")
        return URL(string: "scripturememory://\(route)")
    }
}

struct Provider: TimelineProvider {
    private static let appGroupID = "group.com.griffinbarnard.ScriptureMemory"

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, dueCount: 3, nextReference: "Romans 8:28", collectionName: "Anxiety & Peace", fallbackRoute: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> WidgetEntry {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        let dueCount = defaults?.integer(forKey: "widget_due_count") ?? 0
        let nextRef = defaults?.string(forKey: "widget_next_reference")
        let collection = defaults?.string(forKey: "widget_collection_name") ?? "Hide the Word"
        let fallbackRoute = defaults?.string(forKey: "widget_fallback_route")
        return WidgetEntry(date: .now, dueCount: dueCount, nextReference: nextRef, collectionName: collection, fallbackRoute: fallbackRoute)
    }
}

struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.closed")
                    .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.32))
                Spacer()
            }

            Spacer()

            Text("\(entry.dueCount)")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))

            Text(entry.dueCount == 1 ? "verse due" : "verses due")
                .font(.caption)
                .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.99, green: 0.98, blue: 0.96)
        }
        .widgetURL(entry.deepLinkURL)
    }
}

struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "book.closed")
                    .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.32))

                Spacer()

                Text("\(entry.dueCount)")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))

                Text(entry.dueCount == 1 ? "verse due" : "verses due")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.collectionName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.32))

                Spacer()

                if let nextRef = entry.nextReference {
                    Text("Next up")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
                    Text(nextRef)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))
                } else {
                    Text("All caught up")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.32))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.99, green: 0.98, blue: 0.96)
        }
        .widgetURL(entry.deepLinkURL)
    }
}

@main
struct ScriptureMemoryWidget: Widget {
    let kind = "ScriptureMemoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ScriptureMemoryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hide the Word")
        .description("See how many verses are due for review.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ScriptureMemoryWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
