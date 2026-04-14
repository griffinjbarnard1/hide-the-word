# Hide the Word — Agent Instructions

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
- All persistence goes through `ReviewProgressStore`
- Colors and button styles live in `Theme.swift`
- Card-like containers use `.cardSurface()`
- Plans are the user-facing concept; collections (`VerseSet`) are internal
- CloudKit shared plans use zone-per-group with stable member IDs
- Session flow: `SessionDraft` stores items + index + phase; `SessionFlowView` drives the experience
- Destructive actions require confirmation dialogs

## Style

- Calm, encouraging copy
- Serif fonts for headlines, system for body
- Screen padding: 24pt
- Keep status text terse

## Don't

- Don't hardcode colors in view files
- Don't put button styles in view files
- Don't use `fatalError` for recoverable states
- Don't use display names as CloudKit record identifiers
- Don't skip confirmation on destructive actions
