#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 18.0, macOS 15.0, *)
public enum ScriptureSetOption: String, AppEnum {
    case faith
    case anxiety
    case gospel
    case myVerses

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Collection")
    public static let caseDisplayRepresentations: [ScriptureSetOption: DisplayRepresentation] = [
        .faith: DisplayRepresentation(title: "Faith"),
        .anxiety: DisplayRepresentation(title: "Anxiety"),
        .gospel: DisplayRepresentation(title: "Core Gospel Verses"),
        .myVerses: DisplayRepresentation(title: "My Verses")
    ]

    var setID: UUID {
        switch self {
        case .faith:
            return BuiltInContent.faithSetID
        case .anxiety:
            return BuiltInContent.anxietySetID
        case .gospel:
            return BuiltInContent.gospelSetID
        case .myVerses:
            return BuiltInContent.myVersesSetID
        }
    }
}

@available(iOS 18.0, macOS 15.0, *)
public struct StartTodaysSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Today's Session"
    public static let description = IntentDescription("Open Hide the Word directly to today's review session.")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(AppRouteBuilder.url(for: .todaySession)))
    }
}

@available(iOS 18.0, macOS 15.0, *)
public struct StartFocusedSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Focused Session"
    public static let description = IntentDescription("Open Hide the Word to today's review session with a specific collection selected.")
    public static let openAppWhenRun = true

    @Parameter(title: "Collection")
    public var set: ScriptureSetOption

    public init() {}

    public init(set: ScriptureSetOption) {
        self.set = set
    }

    @MainActor
    public func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(AppRouteBuilder.url(for: .todaySession, setID: set.setID)))
    }
}

@available(iOS 18.0, macOS 15.0, *)
public struct ScriptureMemoryShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: StartTodaysSessionIntent(),
                phrases: [
                    "Start today's session in \(.applicationName)",
                    "Open today's review in \(.applicationName)"
                ],
                shortTitle: "Start Session",
                systemImageName: "book.closed"
            ),
            AppShortcut(
                intent: StartFocusedSessionIntent(),
                phrases: [
                    "Start a \(\.$set) session in \(.applicationName)",
                    "Open \(\.$set) in \(.applicationName)"
                ],
                shortTitle: "Open Verse Set",
                systemImageName: "text.book.closed"
            )
        ]
    }
}
#endif
