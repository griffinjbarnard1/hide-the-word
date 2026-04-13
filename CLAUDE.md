# Hide the Word — Claude Instructions

## Project

Native iOS Bible memorization app. Swift 6, SwiftUI, iOS 18+. XcodeGen for project generation.

## Build

```bash
xcodebuild -project ScriptureMemory.xcodeproj -scheme ScriptureMemoryApp -destination 'generic/platform=iOS Simulator' build
swift test
```

## Structure

- `Sources/ScriptureMemory/` — Swift package: models, scheduling, built-in content, Bible catalog
- `App/` — SwiftUI views and app logic
- `Widget/` — Widget extension
- `project.yml` — XcodeGen spec

## Key patterns

- `AppModel` is the single `@Observable` state object, passed via `.environment(appModel)`
- All persistence goes through `ReviewProgressStore` (UserDefaults + Codable file storage)
- Colors and button styles live in `Theme.swift` — never hardcode colors in views
- Card-like containers use `.cardSurface()` modifier
- Plans are the user-facing concept; collections (`VerseSet`) are internal data layer only
- CloudKit shared plans use zone-per-group pattern with stable member IDs from `CKContainer.userRecordID()`
- Session flow: `SessionDraft` holds items + index + phase; `SessionFlowView` coordinates display/recall/rating/completion
- Destructive actions (leave plan, skip day) require confirmation dialogs

## Style

- Calm, encouraging copy. "No penalties for missing a day."
- Serif fonts for headlines (`.design(.serif)`), system for body
- Padding: 24pt for screen-level, 20pt inside cards (via CardSurface)
- Terse status updates preferred. Don't explain process, just implement.

## Don't

- Don't use `Color.cardBackground` — use `Color.paper`
- Don't put button styles in view files — they go in `Theme.swift`
- Don't use `fatalError` for recoverable states — show graceful fallback
- Don't use display names as CloudKit record identifiers — use stable IDs
- Don't skip confirmation on destructive user actions
