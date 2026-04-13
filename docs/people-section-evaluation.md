# People Section Evaluation (April 13, 2026)

## Snapshot of current implementation

The current social model is **plan-scoped collaboration**, not a global social graph:

- People data is aggregated from shared-plan memberships (`PlanMembership`) inside `SharedPlanGroup` records.
- The app explicitly documents that there is **no global friend list yet**.
- `SocialService` and `SharedPlanManager` are intentionally structured with extension points for future friend-level features.
- `TogetherView` includes a lightweight People tab that lists unique members from joined shared plans, with optional bio preview and profile editing.
- `PeopleView` provides richer sorting and summary cards (plans in common, streak, day, last active), but this appears to be a separate surface from the `TogetherView` People tab.

## Is enough information currently expressed?

### What is already strong

1. **Clarity of scope in code architecture**
   - The code and comments repeatedly communicate that collaboration is plan-local.
2. **Useful lightweight signals in UI**
   - Display name, streak, day progress, last active, and profile snippets cover the essential "who is active" questions.
3. **Low-friction mental model**
   - Users do not need to manage requests/acceptance states, friend inboxes, or moderation flows.

### Current clarity gaps

1. **Potential duplicate People experiences**
   - `TogetherView` has an inline People tab while `PeopleView` has richer aggregation/sorting. If both are intended, their roles should be explicitly differentiated to avoid user confusion.
2. **Missing relationship context**
   - Users can see people but cannot express intent like "close friend", "accountability partner", "mute", or "favorite".
3. **Limited narrative around collaboration**
   - Data points are present, but not always turned into actionable prompts (e.g., "2 members are active today", "Invite one more person to improve consistency").

## Should this be expanded now, or made into a full friend system?

## Recommendation

**Do not jump to a full friend system yet.**

Instead, pursue a **Phase 1.5 "People+" expansion** that keeps plan-scoped simplicity while improving expression and utility.

### Why not full friends now

A true friend system adds substantial complexity:
- Invitations and acceptance flows
- Privacy/visibility controls
- Blocking/reporting and abuse handling
- Cross-plan feed semantics
- Extra backend entities and sync conflict edge cases

Given the app's core value (memorization consistency), this risks shifting effort into social infrastructure before validating that users need persistent friend graphs.

### Suggested phased path

#### Phase 1.5 (recommended now)

1. **Unify People surface**
   - Pick one primary People UI (likely the richer aggregation model) and fold the other into it.
2. **Add soft relationship labels (local-first)**
   - "Accountability partner", "Favorite", "Muted updates" as local metadata only.
3. **Improve explanatory copy**
   - Add one concise paragraph in People empty/populated states explaining that people appear via shared plans (not global adding yet).
4. **Add social nudges, not social graph**
   - Contextual prompts: invite a partner, congratulate streak milestones, resume inactive group.
5. **Introduce privacy affordances early**
   - Profile visibility toggles and optional bio/favorite verse fields already exist—expand controls before friend requests.

#### Phase 2 (only if validated by usage)

Promote to true friend graph only after metrics show demand.
Validation signals:
- Repeat collaboration across multiple plans with same people
- High usage of profile views/labels
- User requests for direct add, persistent circles, or accountability pairs

If those signals are strong, then introduce global `Connection` entities and request/accept workflows.

## Product conclusion

The current People information is **directionally sufficient** for a plan-scoped collaboration product, but not yet **fully coherent** because of duplicate surfaces and limited relationship semantics.

Best next step: **expound the People layer within the existing plan-scoped model** (unification + lightweight relationship metadata + better copy) before building a full friend system.
