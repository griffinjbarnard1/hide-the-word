# Widget Review and Roadmap

## Current Widget Evaluation

### What is already strong
- **Clear primary signal:** The current small and medium widgets center the “due count,” which is the most actionable metric for daily review behavior.
- **Reasonable fallback behavior:** Deep links route users to today’s session when there is work to do and to a fallback route when there is not.
- **Good app-group architecture:** Widget data is written from the app and read by the widget extension with stable keys.
- **Design consistency:** Widget visuals align with the app’s scripture-journal tone (serif count typography + warm neutral palette).

### Current limitations
- **No large widget support:** Home Screen users who prefer larger surfaces can’t pin a richer view.
- **Single data granularity:** There is no at-a-glance breakdown (e.g., “next verse”, “collection”, and primary CTA grouped for planning).
- **No staleness visibility:** Users can’t tell if the content is potentially stale (timeline updates hourly regardless of app activity).
- **No family-specific information density strategy:** Small and medium are implemented, but no roadmap exists for lock screen/accessory or standby families.

## Potential Widget Concepts

### 1) Focus Session Widget (Home: small/medium)
- **Goal:** Maximize session starts.
- **Primary metric:** due count.
- **Secondary metric:** next reference.
- **Best for:** Most users.

### 2) Journey Momentum Widget (Home: medium/large)
- **Goal:** Reinforce consistency over perfection.
- **Primary metric:** streak or recent completion trend.
- **Secondary metric:** this-week completed reviews.
- **Best for:** Habit-forming users.

### 3) Verse Spotlight Widget (small/medium/lock screen)
- **Goal:** Encourage lightweight rehearsal throughout the day.
- **Primary metric:** single verse snippet/reference.
- **Secondary metric:** tap to open rehearsal step.
- **Best for:** Users memorizing one key passage.

### 4) Plan Progress Board (large)
- **Goal:** Give power users a planning surface.
- **Primary metric:** due count + next up + collection context.
- **Secondary metric:** route intent for next review action.
- **Best for:** Users with multi-collection workflows.

## Prioritization
1. **Implement large Home Screen support now** (lowest engineering risk, immediate UX gain).
2. Add optional “staleness” indicator in a follow-up.
3. Add lock screen/accessory family once App Intents surface is expanded.
4. Consider configurable widget intents (choose collection/scope) after usage telemetry supports segmentation.

## Implementation done in this branch
- Added a **systemLarge** widget layout that:
  - Keeps due count as hero metric.
  - Shows collection and next up reference.
  - Includes “all caught up” fallback messaging.
- Enabled **.systemLarge** in supported families.

## Suggested validation checklist
- Verify deep-link behavior for due and no-due states.
- Confirm large widget text truncation for long collection names and references.
- Confirm behavior under empty defaults and app group reset.
- Snapshot test all supported families (small, medium, large).
