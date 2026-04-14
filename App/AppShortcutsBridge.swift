#if canImport(AppIntents)
import AppIntents
import ScriptureMemory

@available(iOS 18.0, macOS 15.0, *)
enum HideTheWordSetOption: String, AppEnum {
    case faith
    case anxiety
    case gospel
    case myVerses

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Collection")
    static let caseDisplayRepresentations: [HideTheWordSetOption: DisplayRepresentation] = [
        .faith: DisplayRepresentation(title: "Faith"),
        .anxiety: DisplayRepresentation(title: "Anxiety"),
        .gospel: DisplayRepresentation(title: "Core Gospel Verses"),
        .myVerses: DisplayRepresentation(title: "My Verses")
    ]

    var setID: UUID {
        switch self {
        case .faith:
            BuiltInContent.faithSetID
        case .anxiety:
            BuiltInContent.anxietySetID
        case .gospel:
            BuiltInContent.gospelSetID
        case .myVerses:
            BuiltInContent.myVersesSetID
        }
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct StartTodaysSessionShortcutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Today's Session"
    static let description = IntentDescription("Open Hide the Word directly to today's review session.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(AppRouteBuilder.url(for: .todaySession)))
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct StartFocusedSessionShortcutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focused Session"
    static let description = IntentDescription("Open Hide the Word to today's review session with a specific collection selected.")
    static let openAppWhenRun = true

    @Parameter(title: "Collection")
    var set: HideTheWordSetOption

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(AppRouteBuilder.url(for: .todaySession, setID: set.setID)))
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct HideTheWordShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .blue }

    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: StartTodaysSessionShortcutIntent(),
                phrases: [
                    "Start today's session in \(.applicationName)",
                    "Open today's review in \(.applicationName)"
                ],
                shortTitle: "Start Session",
                systemImageName: "book.closed"
            ),
            AppShortcut(
                intent: StartFocusedSessionShortcutIntent(),
                phrases: [
                    "Start a \(\.$set) session in \(.applicationName)",
                    "Open \(\.$set) in \(.applicationName)"
                ],
                shortTitle: "Open Collection",
                systemImageName: "text.book.closed"
            )
        ]
    }
}
#endif
