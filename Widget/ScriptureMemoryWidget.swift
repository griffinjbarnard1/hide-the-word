import WidgetKit
import SwiftUI

struct WidgetEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let nextReference: String?
    let collectionName: String
}

struct Provider: TimelineProvider {
    private static let appGroupID = "group.com.griffinbarnard.ScriptureMemory"

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: .now, dueCount: 3, nextReference: "Romans 8:28", collectionName: "Anxiety & Peace")
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
        let collection = defaults?.string(forKey: "widget_collection_name") ?? String(localized: "widget.collection.default", defaultValue: "Hide the Word", table: "Localizable")
        return WidgetEntry(date: .now, dueCount: dueCount, nextReference: nextRef, collectionName: collection)
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

            Text(entry.dueCount == 1
                 ? String(localized: "widget.due.singular", defaultValue: "verse due", table: "Localizable")
                 : String(localized: "widget.due.plural", defaultValue: "verses due", table: "Localizable"))
                .font(.caption)
                .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.99, green: 0.98, blue: 0.96)
        }
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

                Text(entry.dueCount == 1
                     ? String(localized: "widget.due.singular", defaultValue: "verse due", table: "Localizable")
                     : String(localized: "widget.due.plural", defaultValue: "verses due", table: "Localizable"))
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.collectionName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.32))

                Spacer()

                if let nextRef = entry.nextReference {
                    Text(String(localized: "widget.next_up", defaultValue: "Next up", table: "Localizable"))
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
                    Text(nextRef)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))
                } else {
                    Text(String(localized: "widget.all_caught_up", defaultValue: "All caught up", table: "Localizable"))
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
    }
}

@main
struct ScriptureMemoryWidget: Widget {
    let kind = "ScriptureMemoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ScriptureMemoryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.display_name", defaultValue: "Hide the Word", table: "Localizable"))
        .description(String(localized: "widget.description", defaultValue: "See how many verses are due for review.", table: "Localizable"))
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
