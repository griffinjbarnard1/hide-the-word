# Hide the Word

A native iOS app for low-friction Bible memorization. Open, review what's due, study one new verse, rate your recall, done.

## Architecture

```
Sources/ScriptureMemory/     Swift package — models, logic, built-in content
  Models.swift               StudyUnit, VerseProgress, MemorizationPlan, PlanEnrollment, etc.
  BibleCatalog.swift         66-book verse lookup (KJV + WEB bundled)
  BuiltInContent.swift       Verse sets, seeded study units
  BuiltInPlans.swift         15 pre-authored memorization plans
  ReviewScheduler.swift      SM-2 spaced repetition engine
  AppRouting.swift            Deep link routes

App/                         SwiftUI views + app logic
  AppModel.swift             Central @Observable state — sessions, plans, progress, routing
  ReviewProgressStore.swift  UserDefaults + file persistence layer
  Theme.swift                Colors, card surfaces, button styles (dark/light adaptive)
  ScriptureMemoryApp.swift   Entry point, AppDelegate, SceneDelegate (CloudKit shares)

  HomeView.swift             Daily hub — session CTA, plan progress, metrics, mastery
  SessionFlowView.swift      Session coordinator — display → recall → rating → completion
  SessionViews.swift         VerseDisplayView, RecallView, RatingView, CompletionView
  SessionDraft.swift         Session draft model, plan context, items

  JourneyView.swift          Progress dashboard — rhythm heatmap, mastery, activity log
  VerseLibraryView.swift     Bible browser — add single verses, passages, section bundles
  PlanLibraryView.swift      Plan browser — built-in plans, custom plans, free study
  CreatePlanView.swift       Custom plan builder — verse picker, auto day generation
  TogetherView.swift         Social — shared plan groups, member progress, CloudKit sharing
  SharedJourneyManager.swift CloudKit CRUD for shared plans + member progress
  OnboardingView.swift       4-page onboarding — welcome, loop, plan picker, notifications
  SettingsView.swift         Translation, appearance, session size, reminders, type-recall, name

  NotificationManager.swift  Daily reminder scheduling with plan-aware copy + deep-link
  HapticManager.swift        Haptic feedback triggers
  SpeechManager.swift        AVSpeechSynthesizer wrapper for read-aloud
  PassageBreakdown.swift     Splits long passages into recall sections
  PlanShareCard.swift        ImageRenderer share cards for plans
  VerseCardRenderer.swift    ImageRenderer share cards for verses
  WeeklyProgressCard.swift   ImageRenderer share cards for weekly progress
  WidgetDataWriter.swift     Writes due count / next verse to App Group for widget
  EmptyStateView.swift       Reusable empty state component
  RootView.swift             Tab bar — Home, Journey, Together, Library

Widget/                      Widget extension (small + medium)
```

## Tech stack

- Swift 6, SwiftUI, iOS 18+
- XcodeGen (`project.yml`)
- Swift Package for shared models/logic
- SwiftData persistence via `ReviewProgressStore`
- CloudKit for shared plans (zone-per-group pattern)
- ESV API for live translations (KJV/WEB bundled offline)
- StoreKit 2 for contextual review requests

## Design language

- Warm beige palette, serif headings, generous whitespace
- Moss green primary accent, gold secondary
- Adaptive dark mode (charcoal background, lighter accents)
- Soft card surfaces with sand borders and subtle shadows
- Button styles: Primary (moss filled), Secondary (bordered), FilledSoft (tinted)
- Calm, encouraging tone ("no penalties for missing a day")

## Key concepts

**Plans** are the primary organizing concept. A plan is a day-by-day memorization curriculum with goals (learn new, review, full recall, rest). 15 built-in plans ship at launch. Users can create custom plans or use free study mode.

**Session loop**: Display (read verse) → Recall (progressive word masking or type-to-recall with 4 difficulty levels) → Rate (easy/medium/hard) → next item or completion.

**Spaced repetition**: SM-2 variant. Rating adjusts review interval. Hard triggers same-session restudy (deduplicated). Mastery tiers: Learning → Familiar → Memorized → Mastered.

**Social**: CloudKit shared zones. Owner creates a shared plan, invites via system share sheet. Each member syncs independently. Auto-sync on session completion. Stable member IDs via CloudKit user record.

## Configure ESV access

The app looks for `ESV_API_KEY` in either:
1. The process environment
2. The `ESV_API_KEY` build setting in project.yml / xcconfig

Without a key, ESV selection falls back to KJV text silently.

## Build

```bash
# Generate Xcode project (if using xcodegen)
xcodegen

# Build
xcodebuild -project ScriptureMemory.xcodeproj \
  -scheme ScriptureMemoryApp \
  -destination 'generic/platform=iOS Simulator' build

# Tests
swift test
```

## Deep links

| Route | Action |
|-------|--------|
| `scripturememory://session/today` | Start or resume daily session |
| `scripturememory://plans` | Open plan library |
| `scripturememory://library` | Open verse library |
| `scripturememory://journey` | Open journey tab |
| `scripturememory://settings` | Open settings |
| `scripturememory://share/plan-enroll?planID=<uuid>` | Enroll in a built-in plan |
