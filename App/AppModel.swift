import CloudKit
import CryptoKit
import Foundation
import Observation
import ScriptureMemory

enum AppShellTab: String, Hashable, Sendable {
    case home
    case journey
    case together
    case library
}

struct SectionBundleSummary: Identifiable, Hashable {
    let title: String
    let firstUnitID: UUID
    let sectionCount: Int
    let scheduledCount: Int
    let practiceOnlyCount: Int
    let firstReference: String
    let lastReference: String

    var id: String { title }
}

@MainActor
@Observable
final class AppModel {
    private let progressStore: ReviewProgressStore
    private let urlSession: URLSession
    private let esvAPIKey: String?
    private let maxCachedESVVerses = 450

    var selectedCollectionID: UUID
    var selectedTab: AppShellTab
    var preferredTranslation: BibleTranslation
    var sessionSizePreset: SessionSizePreset
    var appearance: AppAppearance
    var hasCompletedOnboarding: Bool
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var typeRecallEnabled: Bool
    var customStudyUnits: [StudyUnit]
    var progressByVerseID: [UUID: VerseProgress]
    var activeRoute: AppRoute?
    var draftSession: SessionDraft?
    var recentReviewEvents: [ReviewEvent]
    var currentStreak: Int
    var lastStreakDate: Date?
    var sessionMilestones: [String]
    var activePlanEnrollment: PlanEnrollment?
    var esvTextByReference: [String: String]
    private var esvVerseCountByReference: [String: Int]
    private var esvReferenceOrder: [String]
    private var esvInFlightReferences: Set<String>

    init(
        progressStore: ReviewProgressStore,
        selectedCollectionID: UUID = BuiltInContent.anxietySetID,
        preferredTranslation: BibleTranslation = .esv,
        sessionSizePreset: SessionSizePreset = .standard,
        customStudyUnits: [StudyUnit]? = nil,
        progressByVerseID: [UUID: VerseProgress]? = nil,
        activeRoute: AppRoute? = nil,
        draftSession: SessionDraft? = nil,
        urlSession: URLSession = .shared,
        esvAPIKey: String? = AppModel.resolveESVAPIKey()
    ) {
        let resolvedCollectionID = progressStore.loadSelectedCollectionID(default: selectedCollectionID)
        let resolvedTranslation = progressStore.loadPreferredTranslation(default: preferredTranslation)
        let resolvedSessionSizePreset = progressStore.loadSessionSizePreset(default: sessionSizePreset)
        let resolvedProgress = progressByVerseID ?? progressStore.loadProgress()
        let loadedCustomStudyUnits = customStudyUnits ?? progressStore.loadCustomStudyUnits()
        let resolvedCustomStudyUnits: [StudyUnit]

        if loadedCustomStudyUnits.isEmpty {
            let legacyVerseIDs = progressStore.loadCustomVerseIDs()
            resolvedCustomStudyUnits = legacyVerseIDs.compactMap { id in
                guard let verse = BuiltInContent.verse(withID: id, setID: BuiltInContent.myVersesSetID) else { return nil }
                return BuiltInContent.studyUnitForSingleVerse(
                    verse,
                    collectionID: BuiltInContent.myVersesSetID,
                    order: legacyVerseIDs.sorted { $0.uuidString < $1.uuidString }.firstIndex(of: id) ?? 0
                )
            }
        } else {
            resolvedCustomStudyUnits = loadedCustomStudyUnits.sorted { $0.order < $1.order }
        }

        self.progressStore = progressStore
        self.urlSession = urlSession
        self.esvAPIKey = esvAPIKey
        self.selectedCollectionID = resolvedCollectionID
        self.selectedTab = .home
        self.preferredTranslation = resolvedTranslation
        self.sessionSizePreset = resolvedSessionSizePreset
        self.appearance = progressStore.loadAppearance(default: .system)
        self.hasCompletedOnboarding = progressStore.loadHasCompletedOnboarding()
        self.reminderEnabled = progressStore.loadReminderEnabled()
        self.reminderHour = progressStore.loadReminderHour()
        self.reminderMinute = progressStore.loadReminderMinute()
        self.typeRecallEnabled = progressStore.loadTypeRecallEnabled()
        self.customStudyUnits = resolvedCustomStudyUnits
        self.progressByVerseID = resolvedProgress
        self.activeRoute = activeRoute
        self.draftSession = draftSession ?? progressStore.loadDraftSession()
        self.recentReviewEvents = progressStore.loadReviewEvents(limit: 200)
        self.currentStreak = progressStore.loadIntPreference("streak_count", default: 0)
        self.lastStreakDate = progressStore.loadDatePreference("streak_last_date")
        self.sessionMilestones = []
        self.activePlanEnrollment = progressStore.loadCodableValue(forKey: "active_plan_enrollment")
        self.esvTextByReference = [:]
        self.esvVerseCountByReference = [:]
        self.esvReferenceOrder = []
        self.esvInFlightReferences = []

        if loadedCustomStudyUnits.isEmpty, !resolvedCustomStudyUnits.isEmpty {
            progressStore.saveCustomStudyUnits(resolvedCustomStudyUnits)
        }

        updateWidgetData()
    }

    var selectedCollection: VerseSet {
        BuiltInContent.collection(for: selectedCollectionID)
    }

    var activeStudyUnits: [StudyUnit] {
        if selectedCollectionID == BuiltInContent.myVersesSetID {
            return scheduledCustomStudyUnits
        }

        return BuiltInContent.builtInStudyUnits(for: selectedCollectionID)
    }

    var scheduledCustomStudyUnits: [StudyUnit] {
        customStudyUnits
            .filter { $0.track == .scheduled }
            .sorted { $0.order < $1.order }
    }

    var practiceOnlyCustomStudyUnits: [StudyUnit] {
        customStudyUnits
            .filter { $0.track == .practiceOnly }
            .sorted { $0.order < $1.order }
    }

    var customSectionBundleSummaries: [SectionBundleSummary] {
        let grouped = Dictionary(grouping: customStudyUnits.filter { $0.title != $0.reference }) { $0.title }
        return grouped.compactMap { title, units in
            guard !units.isEmpty else { return nil }
            let ordered = units.sorted { $0.order < $1.order }
            return SectionBundleSummary(
                title: title,
                firstUnitID: ordered.first?.id ?? UUID(),
                sectionCount: ordered.count,
                scheduledCount: ordered.filter { $0.track == .scheduled }.count,
                practiceOnlyCount: ordered.filter { $0.track == .practiceOnly }.count,
                firstReference: ordered.first?.reference ?? title,
                lastReference: ordered.last?.reference ?? title
            )
        }
        .sorted { $0.title < $1.title }
    }

    var activeVerses: [ScriptureVerse] {
        var resolvedVerses: [UUID: ScriptureVerse] = [:]
        for unit in activeStudyUnits {
            for verseID in unit.verseIDs {
                if let verse = resolveVerse(withID: verseID, setID: unit.collectionID) {
                    resolvedVerses[verseID] = verse
                }
            }
        }

        return resolvedVerses.values.sorted(by: BuiltInContent.sortVerses)
    }

    var hasDraftSession: Bool {
        draftSession?.isFinished == false
    }

    var draftProgressSummary: String? {
        guard let draftSession, !draftSession.items.isEmpty else { return nil }
        let completed = min(draftSession.currentIndex, draftSession.items.count)
        let remaining = max(draftSession.items.count - completed, 0)
        let remainingLabel = remaining == 1 ? "unit left" : "units left"
        return "\(completed) of \(draftSession.items.count) done • \(remaining) \(remainingLabel)"
    }

    var draftCollection: VerseSet? {
        draftSession.map { BuiltInContent.collection(for: $0.collectionID) }
    }

    var draftCollectionDisplayName: String {
        if let planContext = draftSession?.planContext {
            return planContext.planTitle
        }
        if let draftSession, draftSession.isFocusedPractice {
            return draftSession.focusReference ?? "focused practice"
        }
        return draftCollection?.title ?? selectedCollection.title
    }

    var activeSessionTitle: String {
        if let planContext = draftSession?.planContext {
            return "Day \(planContext.dayNumber) • \(planContext.dayTitle)"
        }
        if let draftSession, draftSession.isFocusedPractice {
            return "Focused practice"
        }
        return "Today’s session"
    }

    var currentSessionItem: SessionItem? {
        guard let draftSession, draftSession.currentIndex < draftSession.items.count else { return nil }
        return draftSession.items[draftSession.currentIndex]
    }

    var currentSessionIndex: Int {
        draftSession?.currentIndex ?? 0
    }

    var currentSessionPhase: SessionDraftPhase {
        draftSession?.phase ?? .display
    }

    var currentSessionCount: Int {
        draftSession?.items.count ?? 0
    }

    var sessionPlan: DailySessionPlan {
        buildSessionPreview(on: .now)
    }

    var startedVerseCount: Int {
        activeStudyUnits.filter { progressByVerseID[$0.id]?.isStarted ?? false }.count
    }

    var dueReviewCount: Int {
        sessionPlan.dueReviewCount
    }

    var queuedNewUnitCount: Int {
        sessionPlan.items.filter { $0.kind == .newVerse }.count
    }

    var masteryTierCounts: [MasteryTier: Int] {
        var counts: [MasteryTier: Int] = [:]
        for unit in activeStudyUnits {
            guard let progress = progressByVerseID[unit.id], progress.isStarted else { continue }
            counts[progress.masteryTier, default: 0] += 1
        }
        return counts
    }

    var reviewedThisWeekCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return recentReviewEvents.filter { $0.reviewedAt >= weekAgo }.count
    }

    var weeklyProgressData: WeeklyProgressData {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let weekEvents = recentReviewEvents.filter { $0.reviewedAt >= weekAgo }
        let newStarted = weekEvents.filter { $0.kind == .newVerse }.count
        return WeeklyProgressData(
            reviewCount: weekEvents.count,
            newVersesStarted: newStarted,
            streak: currentStreak,
            masteryChanges: 0,
            collectionName: selectedCollection.title,
            tierCounts: masteryTierCounts
        )
    }

    var strongestStudyUnits: [StudyUnit] {
        activeStudyUnits
            .filter { (progressByVerseID[$0.id]?.reviewCount ?? 0) > 0 }
            .sorted { lhs, rhs in
                let lhsProgress = progressByVerseID[lhs.id]
                let rhsProgress = progressByVerseID[rhs.id]
                if lhsProgress?.intervalDays != rhsProgress?.intervalDays {
                    return (lhsProgress?.intervalDays ?? 0) > (rhsProgress?.intervalDays ?? 0)
                }
                return (lhsProgress?.reviewCount ?? 0) > (rhsProgress?.reviewCount ?? 0)
            }
    }

    var recentlyReviewedUnits: [StudyUnit] {
        let ids = recentReviewEvents.map(\.unitID)
        let map = Dictionary(uniqueKeysWithValues: activeStudyUnits.map { ($0.id, $0) })
        var seen: Set<UUID> = []
        return ids.compactMap { id in
            guard !seen.contains(id), let unit = map[id] else { return nil }
            seen.insert(id)
            return unit
        }
    }

    var olderStartedUnits: [StudyUnit] {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now
        return activeStudyUnits
            .filter { unit in
                guard let progress = progressByVerseID[unit.id], progress.isStarted else { return false }
                guard let lastReviewedAt = progress.lastReviewedAt else { return false }
                return lastReviewedAt < cutoff
            }
            .sorted { lhs, rhs in
                (progressByVerseID[lhs.id]?.lastReviewedAt ?? .distantPast) >
                (progressByVerseID[rhs.id]?.lastReviewedAt ?? .distantPast)
            }
    }

    var nextReviewDate: Date? {
        activeStudyUnits
            .compactMap { progressByVerseID[$0.id]?.nextReviewAt }
            .sorted()
            .first
    }

    var isCustomCollectionEmpty: Bool {
        selectedCollectionID == BuiltInContent.myVersesSetID && scheduledCustomStudyUnits.isEmpty
    }

    var activeCollectionCountLabel: String {
        if selectedCollectionID == BuiltInContent.myVersesSetID {
            let count = scheduledCustomStudyUnits.count
            let label = count == 1 ? "unit" : "units"
            return "\(count) \(label)"
        }

        let count = activeVerses.count
        let label = count == 1 ? "verse" : "verses"
        return "\(count) \(label)"
    }

    var isESVConfigured: Bool {
        !(esvAPIKey?.isEmpty ?? true)
    }

    var preferredTranslationStatusText: String? {
        guard preferredTranslation == .esv, !isESVConfigured else { return nil }
        return "ESV needs an `ESV_API_KEY`. Showing KJV text until it is configured."
    }

    func hasLoadedESVText(for reference: String) -> Bool {
        esvTextByReference[reference] != nil
    }

    func shouldShowESVAttribution(for reference: String) -> Bool {
        preferredTranslation == .esv && hasLoadedESVText(for: reference)
    }

    func translationSupportText(for reference: String) -> String? {
        guard preferredTranslation == .esv else { return nil }
        if hasLoadedESVText(for: reference) {
            return nil
        }
        if isESVConfigured {
            return "Fetching ESV text. KJV is shown until it arrives."
        }
        return "ESV isn't configured here yet. This screen is showing KJV text."
    }

    func selectCollection(_ collectionID: UUID) {
        selectedCollectionID = collectionID
        progressStore.saveSelectedCollectionID(collectionID)
        HapticManager.collectionSwitched()
        updateWidgetData()
    }

    func setPreferredTranslation(_ translation: BibleTranslation) {
        preferredTranslation = translation
        progressStore.savePreferredTranslation(translation)
    }

    func setSessionSizePreset(_ preset: SessionSizePreset) {
        sessionSizePreset = preset
        progressStore.saveSessionSizePreset(preset)
    }

    func setAppearance(_ appearance: AppAppearance) {
        self.appearance = appearance
        progressStore.saveAppearance(appearance)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        progressStore.saveHasCompletedOnboarding()
    }

    func setReminderEnabled(_ enabled: Bool) {
        reminderEnabled = enabled
        progressStore.saveReminderEnabled(enabled)
        if enabled {
            Task { await scheduleReminderWithContext() }
        } else {
            NotificationManager.cancelReminder()
        }
    }

    func setReminderTime(hour: Int, minute: Int) {
        reminderHour = hour
        reminderMinute = minute
        progressStore.saveReminderHour(hour)
        progressStore.saveReminderMinute(minute)
        if reminderEnabled {
            Task { await scheduleReminderWithContext() }
        }
    }

    func scheduleReminderWithContext() async {
        var planInfo: String?
        if let plan = activePlan, let enrollment = activePlanEnrollment, !isActivePlanComplete {
            planInfo = "Day \(enrollment.currentDay) of \(plan.title) is waiting. A few quiet minutes is all it takes."
        }
        await NotificationManager.scheduleDailyReminder(
            at: reminderHour,
            minute: reminderMinute,
            dueCount: dueReviewCount,
            planDayInfo: planInfo
        )
    }

    func setTypeRecallEnabled(_ enabled: Bool) {
        typeRecallEnabled = enabled
        progressStore.saveTypeRecallEnabled(enabled)
    }

    func containsSingleVerseUnit(_ verseID: UUID) -> Bool {
        customStudyUnits.contains { $0.kind == .singleVerse && $0.verseIDs == [verseID] }
    }

    func track(for verseID: UUID) -> StudyUnitTrack? {
        customStudyUnits.first(where: { $0.kind == .singleVerse && $0.verseIDs == [verseID] })?.track
    }

    func containsPassageUnit(reference: String) -> Bool {
        customStudyUnits.contains {
            $0.kind == .passage && $0.reference == reference
        }
    }

    func containsSectionBundle(reference: String) -> Bool {
        customStudyUnits.contains {
            $0.kind == .passage && $0.title == reference && $0.reference != reference
        }
    }

    func toggleSingleVerseUnit(for verse: ScriptureVerse) {
        if let existingIndex = customStudyUnits.firstIndex(where: { $0.kind == .singleVerse && $0.id == verse.id }) {
            customStudyUnits.remove(at: existingIndex)
        } else {
            let newUnit = BuiltInContent.studyUnitForSingleVerse(
                verse,
                collectionID: BuiltInContent.myVersesSetID,
                order: nextCustomOrder
            )
            customStudyUnits.append(newUnit)
        }

        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
    }

    @discardableResult
    func addSingleVerseUnits(for verses: [ScriptureVerse], track: StudyUnitTrack) -> [StudyUnit] {
        let newUnits = verses
            .sorted(by: BuiltInContent.sortVerses)
            .filter { verse in
                !customStudyUnits.contains { $0.kind == .singleVerse && $0.id == verse.id }
            }
            .map { verse in
                StudyUnit(
                    id: verse.id,
                    collectionID: BuiltInContent.myVersesSetID,
                    order: nextCustomOrder + customStudyUnits.count,
                    kind: .singleVerse,
                    track: track,
                    title: verse.reference,
                    reference: verse.reference,
                    kjvText: verse.kjvText,
                    webText: verse.webText,
                    verseIDs: [verse.id]
                )
            }

        guard !newUnits.isEmpty else { return [] }
        customStudyUnits.append(contentsOf: newUnits)
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
        selectCollection(BuiltInContent.myVersesSetID)
        return newUnits
    }

    func addSingleVerseUnits(for verses: [ScriptureVerse]) {
        addSingleVerseUnits(for: verses, track: .scheduled)
    }

    func createPassageUnit(from verseIDs: [UUID]) {
        let verses = verseIDs
            .compactMap { resolveVerse(withID: $0, setID: BuiltInContent.myVersesSetID) }
            .sorted(by: BuiltInContent.sortVerses)
        createPassageUnit(from: verses)
    }

    @discardableResult
    func createPassageUnit(from verses: [ScriptureVerse], track: StudyUnitTrack = .scheduled) -> StudyUnit? {
        let orderedVerses = verses.sorted(by: BuiltInContent.sortVerses)
        guard orderedVerses.count >= 2 else { return nil }
        let reference = BuiltInContent.reference(for: orderedVerses)
        guard !containsPassageUnit(reference: reference) else { return nil }

        let unit = BuiltInContent.passageStudyUnit(
            id: UUID(),
            collectionID: BuiltInContent.myVersesSetID,
            order: nextCustomOrder,
            track: track,
            verses: orderedVerses
        )

        customStudyUnits.append(unit)
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
        selectCollection(BuiltInContent.myVersesSetID)
        return unit
    }

    @discardableResult
    func createPassageSectionUnits(from verses: [ScriptureVerse], track: StudyUnitTrack = .scheduled) -> [StudyUnit] {
        let orderedVerses = verses.sorted(by: BuiltInContent.sortVerses)
        guard orderedVerses.count >= 2 else { return [] }

        let parentReference = BuiltInContent.reference(for: orderedVerses)
        guard !containsSectionBundle(reference: parentReference) else { return [] }

        let translationForBreakdown: BibleTranslation = preferredTranslation == .esv ? .kjv : preferredTranslation
        let groups = PassageBreakdown.groupedVerses(for: orderedVerses, translation: translationForBreakdown)
        guard groups.count > 1 else {
            if let unit = createPassageUnit(from: orderedVerses, track: track) {
                return [unit]
            }
            return []
        }

        let baseOrder = nextCustomOrder
        let units = groups.enumerated().map { index, group in
            let reference = BuiltInContent.reference(for: group)
            return StudyUnit(
                id: UUID(),
                collectionID: BuiltInContent.myVersesSetID,
                order: baseOrder + index,
                kind: .passage,
                track: track,
                title: parentReference,
                reference: reference,
                kjvText: group.map(\.kjvText).joined(separator: " "),
                webText: group.map(\.webText).joined(separator: " "),
                verseIDs: group.map(\.id)
            )
        }

        customStudyUnits.append(contentsOf: units)
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
        selectCollection(BuiltInContent.myVersesSetID)
        return units
    }

    func studyContextLabel(for unit: StudyUnit) -> String? {
        guard unit.title != unit.reference else { return nil }
        if unit.title == "Full passage" {
            return "Full passage recall"
        }
        return "From \(unit.title)"
    }

    func removeCustomStudyUnit(_ unitID: UUID) {
        customStudyUnits.removeAll { $0.id == unitID && $0.collectionID == BuiltInContent.myVersesSetID }
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
    }

    func studyUnit(withID id: UUID) -> StudyUnit? {
        if let customUnit = customStudyUnits.first(where: { $0.id == id }) {
            return customUnit
        }

        for set in BuiltInContent.verseSets {
            if let builtInUnit = BuiltInContent.builtInStudyUnits(for: set.id).first(where: { $0.id == id }) {
                return builtInUnit
            }
        }

        return nil
    }

    func moveCustomStudyUnit(_ unitID: UUID, to track: StudyUnitTrack) {
        guard let index = customStudyUnits.firstIndex(where: { $0.id == unitID }) else { return }
        let unit = customStudyUnits[index]
        guard unit.track != track else { return }

        customStudyUnits[index] = StudyUnit(
            id: unit.id,
            collectionID: unit.collectionID,
            order: unit.order,
            kind: unit.kind,
            track: track,
            title: unit.title,
            reference: unit.reference,
            kjvText: unit.kjvText,
            webText: unit.webText,
            verseIDs: unit.verseIDs
        )
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
    }

    func openCollections() {
        activeRoute = .plans
    }

    // MARK: - Plan Enrollment

    var activePlan: MemorizationPlan? {
        guard let enrollment = activePlanEnrollment else { return nil }
        return BuiltInPlans.plan(withID: enrollment.planID)
            ?? customPlans.first(where: { $0.id == enrollment.planID })
    }

    var isActivePlanComplete: Bool {
        guard let plan = activePlan, let enrollment = activePlanEnrollment else { return false }
        return enrollment.completedDays.contains(plan.duration) && enrollment.currentDay > plan.duration
    }

    var customPlans: [MemorizationPlan] {
        progressStore.loadCodableValue(forKey: "custom_plans") ?? []
    }

    var currentPlanDay: PlanDay? {
        guard let plan = activePlan, let enrollment = activePlanEnrollment, !isActivePlanComplete else { return nil }
        return plan.days.first { $0.dayNumber == enrollment.currentDay }
    }

    var planDayProgress: String? {
        guard let plan = activePlan, let enrollment = activePlanEnrollment else { return nil }
        if isActivePlanComplete {
            return "Completed"
        }
        return "Day \(enrollment.currentDay) of \(plan.duration)"
    }

    func enrollInPlan(_ plan: MemorizationPlan) {
        activePlanEnrollment = PlanEnrollment(planID: plan.id, startedAt: .now)
        progressStore.saveCodableValue(activePlanEnrollment, forKey: "active_plan_enrollment")

        // Materialize day 1 into My Verses so the content is visible outside the session too.
        materializePlanDay(1, from: plan)
    }

    func advancePlanDay() {
        guard var enrollment = activePlanEnrollment, let plan = activePlan else { return }
        enrollment.completedDays.insert(enrollment.currentDay)
        if enrollment.currentDay < plan.duration {
            enrollment.currentDay += 1
            materializePlanDay(enrollment.currentDay, from: plan)
        } else {
            enrollment.currentDay = plan.duration + 1
        }
        enrollment.lastActiveAt = .now
        activePlanEnrollment = enrollment
        progressStore.saveCodableValue(enrollment, forKey: "active_plan_enrollment")
    }

    func leavePlan() {
        activePlanEnrollment = nil
        progressStore.saveCodableValue(nil as PlanEnrollment?, forKey: "active_plan_enrollment")
    }

    func saveCustomPlan(_ plan: MemorizationPlan) {
        var plans = customPlans
        plans.append(plan)
        progressStore.saveCodableValue(plans, forKey: "custom_plans")
    }

    private func materializePlanDay(_ dayNumber: Int, from plan: MemorizationPlan) {
        guard let day = plan.days.first(where: { $0.dayNumber == dayNumber }) else { return }
        guard day.goal == .learnNew || day.goal == .fullRecall else { return }

        for ref in day.verseReferences {
            // Check if this verse is already in custom study units
            let alreadyExists = customStudyUnits.contains { unit in
                unit.verseIDs.contains { verseID in
                    guard let verse = BuiltInContent.verse(withID: verseID) else { return false }
                    return verse.bookID == ref.bookID && verse.chapter == ref.chapter && verse.verse == ref.verse
                }
            }

            if !alreadyExists {
                if let verse = BibleCatalog.verse(bookID: ref.bookID, chapter: ref.chapter, verse: ref.verse, setID: BuiltInContent.myVersesSetID, order: nextCustomOrder) {
                    let unit = BuiltInContent.studyUnitForSingleVerse(verse, collectionID: BuiltInContent.myVersesSetID, order: nextCustomOrder)
                    customStudyUnits.append(unit)
                }
            }
        }
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
        selectCollection(BuiltInContent.myVersesSetID)
    }

    private func buildSessionPreview(on date: Date) -> DailySessionPlan {
        if let preview = buildPlanSessionPreview(on: date) {
            return preview
        }

        return ReviewScheduler.buildPlan(
            units: activeStudyUnits,
            progressByUnitID: progressByVerseID,
            on: date,
            config: sessionSizePreset.sessionConfig
        )
    }

    private func makePlanDraftIfAvailable(on date: Date) -> SessionDraft? {
        guard
            let enrollment = activePlanEnrollment,
            let plan = activePlan,
            let day = currentPlanDay
        else {
            return nil
        }

        let sessionPlan = buildPlanSession(for: plan, enrollment: enrollment, day: day, on: date)
        let context = SessionDraftPlanContext(
            planID: plan.id,
            planTitle: plan.title,
            dayNumber: day.dayNumber,
            dayTitle: day.title,
            dayGoal: day.goal
        )

        return SessionDraft(
            collectionID: BuiltInContent.myVersesSetID,
            items: sessionPlan.items,
            currentIndex: 0,
            phase: sessionPlan.items.isEmpty ? .complete : .display,
            restudiedUnitIDs: [],
            startedAt: date,
            mode: .planDaily,
            focusReference: day.title,
            planContext: context
        )
    }

    private func buildPlanSessionPreview(on date: Date) -> DailySessionPlan? {
        guard
            let enrollment = activePlanEnrollment,
            let plan = activePlan,
            let day = currentPlanDay
        else {
            return nil
        }

        return buildPlanSession(for: plan, enrollment: enrollment, day: day, on: date)
    }

    private func buildPlanSession(
        for plan: MemorizationPlan,
        enrollment: PlanEnrollment,
        day: PlanDay,
        on date: Date
    ) -> DailySessionPlan {
        let config = sessionSizePreset.sessionConfig
        let dayItems = planDayItems(for: day, in: plan)
        let dayVerseIDs = Set(day.verseReferences.compactMap { reference in
            BibleCatalog.verse(
                bookID: reference.bookID,
                chapter: reference.chapter,
                verse: reference.verse,
                setID: BuiltInContent.myVersesSetID
            )?.id
        })

        let reviewPool = planStudyPoolUnits(for: plan, through: enrollment.currentDay)
            .filter { unit in
                !unit.verseIDs.contains(where: dayVerseIDs.contains)
            }

        let dueReviewUnits = reviewPool
            .filter { unit in
                guard let progress = progressByVerseID[unit.id] else { return false }
                return progress.isDue(on: date)
            }
            .sorted { lhs, rhs in
                let lhsDate = progressByVerseID[lhs.id]?.nextReviewAt ?? .distantFuture
                let rhsDate = progressByVerseID[rhs.id]?.nextReviewAt ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.order < rhs.order
                }
                return lhsDate < rhsDate
            }

        let reviewCapacity: Int
        switch day.goal {
        case .reviewOnly, .rest:
            reviewCapacity = config.maxTotalItems
        case .learnNew, .fullRecall:
            reviewCapacity = max(config.maxTotalItems - dayItems.count, 0)
        }

        let reviewItems = dueReviewUnits
            .prefix(reviewCapacity)
            .map { SessionItem(unit: $0, kind: .review) }

        let items: [SessionItem]
        if day.goal == .reviewOnly || day.goal == .rest {
            items = reviewItems.isEmpty ? planFallbackItems(from: reviewPool, limit: 1) : reviewItems
        } else {
            items = dayItems + reviewItems
        }

        return DailySessionPlan(
            generatedAt: date,
            items: items,
            dueReviewCount: dueReviewUnits.count
        )
    }

    private func planDayItems(for day: PlanDay, in plan: MemorizationPlan) -> [SessionItem] {
        let verses = resolvePlanVerses(day.verseReferences)
        switch day.goal {
        case .learnNew:
            return planLearningItems(for: verses, plan: plan, day: day)
        case .fullRecall:
            return planFullRecallItems(for: verses, plan: plan, day: day)
        case .reviewOnly, .rest:
            return []
        }
    }

    private func planLearningItems(for verses: [ScriptureVerse], plan: MemorizationPlan, day: PlanDay) -> [SessionItem] {
        guard !verses.isEmpty else { return [] }
        if verses.count == 1, let verse = verses.first {
            let unit = BuiltInContent.studyUnitForSingleVerse(
                verse,
                collectionID: BuiltInContent.myVersesSetID,
                order: day.dayNumber * 100
            )
            let kind: SessionItemKind = (progressByVerseID[unit.id]?.isStarted ?? false) ? .review : .newVerse
            return [SessionItem(unit: unit, kind: kind)]
        }

        let groups = PassageBreakdown.groupedVerses(
            for: verses,
            translation: preferredTranslation == .esv ? .kjv : preferredTranslation
        )

        return groups.enumerated().map { index, group in
            let reference = BuiltInContent.reference(for: group)
            let unit = BuiltInContent.passageStudyUnit(
                id: planUnitID(
                    planID: plan.id,
                    dayNumber: day.dayNumber,
                    role: "learn",
                    index: index,
                    reference: reference
                ),
                collectionID: BuiltInContent.myVersesSetID,
                order: day.dayNumber * 100 + index,
                verses: group
            )
            return SessionItem(unit: unit, kind: .newVerse)
        }
    }

    private func planFullRecallItems(for verses: [ScriptureVerse], plan: MemorizationPlan, day: PlanDay) -> [SessionItem] {
        guard !verses.isEmpty else { return [] }
        if verses.count == 1, let verse = verses.first {
            let unit = BuiltInContent.studyUnitForSingleVerse(
                verse,
                collectionID: BuiltInContent.myVersesSetID,
                order: day.dayNumber * 100
            )
            return [SessionItem(unit: unit, kind: .review)]
        }

        let translation = preferredTranslation == .esv ? .kjv : preferredTranslation
        let groups = PassageBreakdown.groupedVerses(for: verses, translation: translation)
        var items = groups.enumerated().map { index, group in
            let reference = BuiltInContent.reference(for: group)
            let unit = BuiltInContent.passageStudyUnit(
                id: planUnitID(
                    planID: plan.id,
                    dayNumber: day.dayNumber,
                    role: "section-recall",
                    index: index,
                    reference: reference
                ),
                collectionID: BuiltInContent.myVersesSetID,
                order: day.dayNumber * 100 + index,
                verses: group
            )
            return SessionItem(unit: unit, kind: .review)
        }

        if groups.count > 1 {
            let fullUnit = BuiltInContent.passageStudyUnit(
                id: planUnitID(
                    planID: plan.id,
                    dayNumber: day.dayNumber,
                    role: "full-recall",
                    index: groups.count,
                    reference: BuiltInContent.reference(for: verses)
                ),
                collectionID: BuiltInContent.myVersesSetID,
                order: day.dayNumber * 100 + groups.count,
                verses: verses
            )
            items.append(SessionItem(unit: fullUnit, kind: .review))
        }

        return items
    }

    private func planStudyPoolUnits(for plan: MemorizationPlan, through dayNumber: Int) -> [StudyUnit] {
        let references = plan.days
            .filter { $0.dayNumber <= dayNumber }
            .flatMap(\.verseReferences)

        let verses = resolvePlanVerses(references)
        return verses.enumerated().map { index, verse in
            BuiltInContent.studyUnitForSingleVerse(
                verse,
                collectionID: BuiltInContent.myVersesSetID,
                order: index + 1
            )
        }
    }

    private func resolvePlanVerses(_ references: [VerseReference]) -> [ScriptureVerse] {
        var seen: Set<UUID> = []
        return references.compactMap { reference in
            BibleCatalog.verse(
                bookID: reference.bookID,
                chapter: reference.chapter,
                verse: reference.verse,
                setID: BuiltInContent.myVersesSetID
            )
        }
        .filter { verse in
            seen.insert(verse.id).inserted
        }
        .sorted(by: BuiltInContent.sortVerses)
    }

    private func planFallbackItems(from units: [StudyUnit], limit: Int) -> [SessionItem] {
        units
            .filter { progressByVerseID[$0.id]?.isStarted ?? false }
            .sorted { lhs, rhs in
                let lhsLast = progressByVerseID[lhs.id]?.lastReviewedAt ?? .distantPast
                let rhsLast = progressByVerseID[rhs.id]?.lastReviewedAt ?? .distantPast
                if lhsLast == rhsLast {
                    return lhs.order < rhs.order
                }
                return lhsLast < rhsLast
            }
            .prefix(limit)
            .map { SessionItem(unit: $0, kind: .review) }
    }

    private func planUnitID(
        planID: UUID,
        dayNumber: Int,
        role: String,
        index: Int,
        reference: String
    ) -> UUID {
        let seed = "hide-the-word-plan:\(planID.uuidString):\(dayNumber):\(role):\(index):\(reference)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func derivedSharedPassageUnitID(title: String, reference: String, index: Int) -> UUID {
        let seed = "hide-the-word-shared:\(title):\(reference):\(index)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    func openVerseLibrary() {
        selectedTab = .library
        if activeRoute != .todaySession {
            activeRoute = nil
        }
    }

    func openJourney() {
        selectedTab = .journey
        if activeRoute != .todaySession {
            activeRoute = nil
        }
    }

    func openHome() {
        selectedTab = .home
        if activeRoute != .todaySession {
            activeRoute = nil
        }
    }

    func openSettings() {
        activeRoute = .settings
    }

    func openPlans() {
        activeRoute = .plans
    }

    func dismissActiveRoute() {
        activeRoute = nil
    }

    func startOrResumeSession() {
        if let draftSession, draftSession.isFinished == false {
            activeRoute = .todaySession
            return
        }

        startFreshSession()
    }

    func startFreshSession() {
        if let draft = makePlanDraftIfAvailable(on: .now) {
            draftSession = draft
            progressStore.saveDraftSession(draftSession)
            activeRoute = .todaySession
            return
        }

        let plan = ReviewScheduler.buildPlan(
            units: activeStudyUnits,
            progressByUnitID: progressByVerseID,
            on: .now,
            config: sessionSizePreset.sessionConfig
        )

        draftSession = SessionDraft(
            collectionID: selectedCollectionID,
            items: plan.items,
            currentIndex: 0,
            phase: plan.items.isEmpty ? .complete : .display,
            restudiedUnitIDs: [],
            startedAt: .now,
            mode: .daily,
            focusReference: nil,
            planContext: nil
        )
        progressStore.saveDraftSession(draftSession)
        activeRoute = .todaySession
    }

    func startFocusedPractice(for unit: StudyUnit) {
        startFocusedPractice(for: [unit], focusReference: unit.reference)
    }

    func startFocusedPractice(for units: [StudyUnit], focusReference: String) {
        let orderedUnits = units.sorted { $0.order < $1.order }
        guard !orderedUnits.isEmpty else { return }

        var items = orderedUnits.map { SessionItem(unit: $0, kind: .review) }

        // For multi-section bundles, append a combined full-passage recall at the end
        if orderedUnits.count > 1, orderedUnits.first?.title != orderedUnits.first?.reference {
            let combinedKJV = orderedUnits.map(\.kjvText).joined(separator: " ")
            let combinedWEB = orderedUnits.map(\.webText).joined(separator: " ")
            let allVerseIDs = orderedUnits.flatMap(\.verseIDs)
            let combinedUnit = StudyUnit(
                id: UUID(),
                collectionID: orderedUnits[0].collectionID,
                order: orderedUnits.last!.order + 1,
                kind: .passage,
                track: orderedUnits[0].track,
                title: "Full passage",
                reference: focusReference,
                kjvText: combinedKJV,
                webText: combinedWEB,
                verseIDs: allVerseIDs
            )
            items.append(SessionItem(unit: combinedUnit, kind: .review))
        }

        draftSession = SessionDraft(
            collectionID: orderedUnits[0].collectionID,
            items: items,
            currentIndex: 0,
            phase: .display,
            restudiedUnitIDs: [],
            startedAt: .now,
            mode: .focusedPractice,
            focusReference: focusReference,
            planContext: nil
        )
        progressStore.saveDraftSession(draftSession)
        activeRoute = .todaySession
    }

    func sectionBundleUnits(for unit: StudyUnit) -> [StudyUnit] {
        guard unit.title != unit.reference else { return [] }
        return customStudyUnits
            .filter { $0.title == unit.title }
            .sorted { $0.order < $1.order }
    }

    func sectionBundleUnits(forTitle title: String) -> [StudyUnit] {
        customStudyUnits
            .filter { $0.title == title && $0.title != $0.reference }
            .sorted { $0.order < $1.order }
    }

    func moveSectionBundle(_ title: String, to track: StudyUnitTrack) {
        let bundleIDs = Set(sectionBundleUnits(forTitle: title).map(\.id))
        guard !bundleIDs.isEmpty else { return }
        customStudyUnits = customStudyUnits.map { unit in
            guard bundleIDs.contains(unit.id), unit.track != track else { return unit }
            return StudyUnit(
                id: unit.id,
                collectionID: unit.collectionID,
                order: unit.order,
                kind: unit.kind,
                track: track,
                title: unit.title,
                reference: unit.reference,
                kjvText: unit.kjvText,
                webText: unit.webText,
                verseIDs: unit.verseIDs
            )
        }
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
    }

    func removeSectionBundle(_ title: String) {
        customStudyUnits.removeAll { $0.title == title && $0.title != $0.reference }
        normalizeCustomUnitOrder()
        persistCustomStudyUnits()
    }

    func leaveSession() {
        progressStore.saveDraftSession(draftSession)
        activeRoute = nil
    }

    func setSessionPhase(_ phase: SessionDraftPhase) {
        guard draftSession != nil else { return }
        draftSession?.phase = phase
        progressStore.saveDraftSession(draftSession)
    }

    func completeCurrentReview(rating: ReviewRating, now: Date = .now) {
        guard var draftSession, draftSession.currentIndex < draftSession.items.count else { return }
        let currentItem = draftSession.items[draftSession.currentIndex]
        let updatedProgress = ReviewScheduler.apply(
            rating: rating,
            to: currentItem.unit,
            existing: progressByVerseID[currentItem.unit.id],
            reviewedAt: now
        )
        progressByVerseID[currentItem.unit.id] = updatedProgress
        progressStore.save(updatedProgress)
        let event = ReviewEvent(
            unitID: currentItem.unit.id,
            unitReference: currentItem.unit.reference,
            reviewedAt: now,
            rating: rating,
            kind: currentItem.kind
        )
        recentReviewEvents.insert(event, at: 0)
        if recentReviewEvents.count > 200 {
            recentReviewEvents.removeLast(recentReviewEvents.count - 200)
        }
        progressStore.saveReviewEvent(event)

        if rating == .hard, !draftSession.restudiedUnitIDs.contains(currentItem.unit.id) {
            draftSession.items.append(SessionItem(unit: currentItem.unit, kind: .restudy))
            draftSession.restudiedUnitIDs.insert(currentItem.unit.id)
        }

        let previousTier = (progressByVerseID[currentItem.unit.id].map { MasteryTier.from(reviewCount: $0.reviewCount - 1, intervalDays: $0.intervalDays) })
        let newTier = updatedProgress.masteryTier

        draftSession.currentIndex += 1
        draftSession.phase = draftSession.currentIndex >= draftSession.items.count ? .complete : .display
        self.draftSession = draftSession
        progressStore.saveDraftSession(draftSession)

        updateStreak()
        detectMilestones(previousTier: previousTier, newTier: newTier, unit: currentItem.unit)
        updateWidgetData()
    }

    private func updateStreak() {
        let today = Calendar.current.startOfDay(for: .now)
        if let last = lastStreakDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let daysBetween = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween == 0 {
                return // Already counted today
            } else if daysBetween == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        lastStreakDate = today
        progressStore.saveIntPreference(currentStreak, forKey: "streak_count")
        progressStore.saveDatePreference(today, forKey: "streak_last_date")
    }

    private func detectMilestones(previousTier: MasteryTier?, newTier: MasteryTier, unit: StudyUnit) {
        var milestones: [String] = []

        // Tier promotion
        if let prev = previousTier, newTier > prev {
            milestones.append("\(unit.reference) is now \(newTier.title)")
        }

        // Total review count milestones
        let totalReviews = progressByVerseID.values.reduce(0) { $0 + $1.reviewCount }
        for threshold in [10, 25, 50, 100, 250, 500, 1000] {
            if totalReviews == threshold {
                milestones.append("\(threshold) total reviews completed")
            }
        }

        // Mastered count milestones
        let masteredCount = progressByVerseID.values.filter { $0.masteryTier == .mastered }.count
        for threshold in [1, 5, 10, 25, 50] {
            if masteredCount == threshold {
                milestones.append("\(threshold) verse\(threshold == 1 ? "" : "s") mastered")
            }
        }

        // Streak milestones
        for threshold in [7, 14, 30, 60, 100] {
            if currentStreak == threshold {
                milestones.append("\(threshold)-day streak")
            }
        }

        if !milestones.isEmpty {
            sessionMilestones.append(contentsOf: milestones)
        }
    }

    private func updateWidgetData() {
        let nextRef = activeStudyUnits
            .compactMap { unit -> (String, Date)? in
                guard let next = progressByVerseID[unit.id]?.nextReviewAt else { return nil }
                return (unit.reference, next)
            }
            .sorted { $0.1 < $1.1 }
            .first?.0
        let fallbackRoute: AppRoute? = if dueReviewCount == 0 {
            activePlanEnrollment == nil ? .library : .journey
        } else {
            nil
        }
        WidgetData.write(
            dueCount: dueReviewCount,
            nextReference: nextRef,
            collectionName: selectedCollection.title,
            fallbackRoute: fallbackRoute
        )
    }

    func exportDataURL() -> URL? {
        struct ExportData: Codable {
            let exportedAt: Date
            let selectedCollectionID: UUID
            let preferredTranslation: String
            let sessionSizePreset: String
            let streak: Int
            let customStudyUnits: [StudyUnit]
            let progress: [UUID: VerseProgress]
            let reviewEvents: [ReviewEvent]
        }

        let data = ExportData(
            exportedAt: .now,
            selectedCollectionID: selectedCollectionID,
            preferredTranslation: preferredTranslation.rawValue,
            sessionSizePreset: sessionSizePreset.rawValue,
            streak: currentStreak,
            customStudyUnits: customStudyUnits,
            progress: progressByVerseID,
            reviewEvents: recentReviewEvents
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(data) else { return nil }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("HideTheWord-backup.json")
        try? jsonData.write(to: tempURL)
        return tempURL
    }

    func clearCompletedSession() {
        let completedDraft = draftSession
        draftSession = nil
        progressStore.saveDraftSession(nil)
        activeRoute = nil

        // Only advance an enrolled plan when the completed session was generated for that plan day.
        if completedDraft?.isPlanDaily == true {
            advancePlanDay()
        }

        // Refresh notification with updated due count and plan context; clear badge
        if reminderEnabled {
            Task { await scheduleReminderWithContext() }
        }
        Task { await NotificationManager.clearBadge() }

        // Auto-sync progress to shared plans
        if let enrollment = activePlanEnrollment {
            Task {
                let manager = SharedPlanManager.shared
                let groups = await {
                    await manager.fetchGroups()
                    return manager.groups
                }()
                for group in groups where group.planID == enrollment.planID {
                    let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: group.zoneOwnerName)
                    _ = await manager.syncMyProgress(
                        groupZoneID: zoneID,
                        memberName: userDisplayName,
                        currentDay: enrollment.currentDay,
                        completedDays: enrollment.completedDays,
                        streak: currentStreak
                    )
                }
                await manager.fetchGroups()
            }
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "scripturememory" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let requestedCollectionID = components?.queryItems?.first(where: { $0.name == "setID" })?.value.flatMap(UUID.init(uuidString:))
        if let requestedCollectionID, BuiltInContent.verseSets.contains(where: { $0.id == requestedCollectionID }) {
            selectCollection(requestedCollectionID)
        }

        let route = url.host.map { host -> String in
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? host : "\(host)/\(path)"
        } ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch route {
        case AppRoute.todaySession.rawValue:
            startOrResumeSession()
        case AppRoute.verseSets.rawValue:
            openCollections()
        case AppRoute.library.rawValue:
            openVerseLibrary()
        case AppRoute.journey.rawValue:
            openJourney()
        case AppRoute.settings.rawValue:
            openSettings()
        case AppRoute.plans.rawValue:
            openPlans()
        case _ where route.hasPrefix("share/plan-enroll"):
            if let planIDString = components?.queryItems?.first(where: { $0.name == "planID" })?.value,
               let planID = UUID(uuidString: planIDString),
               let plan = BuiltInPlans.plan(withID: planID) ?? customPlans.first(where: { $0.id == planID }) {
                enrollInPlan(plan)
                openPlans()
            }
        case _ where route.hasPrefix("share/"):
            handleSharePlanURL(components)
        default:
            return
        }
    }

    // MARK: - Shared Journey Plan

    func sharePassagePlanURL(bookID: String, startChapter: Int, startVerse: Int, endChapter: Int, endVerse: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "scripturememory"
        components.host = "share"
        components.path = "/plan"
        components.queryItems = [
            URLQueryItem(name: "book", value: bookID),
            URLQueryItem(name: "sc", value: String(startChapter)),
            URLQueryItem(name: "sv", value: String(startVerse)),
            URLQueryItem(name: "ec", value: String(endChapter)),
            URLQueryItem(name: "ev", value: String(endVerse)),
        ]
        return components.url
    }

    func shareURLForSectionBundle(title: String) -> URL? {
        let units = sectionBundleUnits(forTitle: title)
        guard !units.isEmpty else { return nil }
        let allVerseIDs = units.flatMap(\.verseIDs)
        let verses = allVerseIDs.compactMap { BuiltInContent.verse(withID: $0) }
        guard let first = verses.min(by: { ($0.bookNumber, $0.chapter, $0.verse) < ($1.bookNumber, $1.chapter, $1.verse) }),
              let last = verses.max(by: { ($0.bookNumber, $0.chapter, $0.verse) < ($1.bookNumber, $1.chapter, $1.verse) })
        else { return nil }
        return sharePassagePlanURL(
            bookID: first.bookID,
            startChapter: first.chapter,
            startVerse: first.verse,
            endChapter: last.chapter,
            endVerse: last.verse
        )
    }

    func passageVerses(
        bookID: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int
    ) -> [ScriptureVerse] {
        resolveVerseRange(
            bookID: bookID,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse
        )
    }

    func passageReference(
        bookID: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int
    ) -> String {
        let verses = passageVerses(
            bookID: bookID,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse
        )
        return BuiltInContent.reference(for: verses)
    }

    func passagePlanSummary(
        bookID: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int
    ) -> PassagePlanSummary? {
        let verses = passageVerses(
            bookID: bookID,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse
        )
        guard !verses.isEmpty else { return nil }
        let translation = preferredTranslation == .esv ? .kjv : preferredTranslation
        return PassageBreakdown.summary(for: verses, translation: translation)
    }

    func hasSavedSectionBundle(
        bookID: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int
    ) -> Bool {
        let reference = passageReference(
            bookID: bookID,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse
        )
        return containsSectionBundle(reference: reference)
    }

    func saveJourneyPassage(
        bookID: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int,
        track: StudyUnitTrack = .scheduled
    ) -> [StudyUnit] {
        let verses = passageVerses(
            bookID: bookID,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse
        )
        guard !verses.isEmpty else { return [] }
        return createPassageSectionUnits(from: verses, track: track)
    }

    func startFocusedPractice(
        bookID: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int,
        title: String? = nil
    ) {
        let verses = passageVerses(
            bookID: bookID,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse
        )
        guard !verses.isEmpty else { return }

        let focusReference = title ?? BuiltInContent.reference(for: verses)
        let translation = preferredTranslation == .esv ? .kjv : preferredTranslation
        let groups = PassageBreakdown.groupedVerses(for: verses, translation: translation)
        let units: [StudyUnit]

        if groups.count <= 1 {
            units = [
                BuiltInContent.passageStudyUnit(
                    id: derivedSharedPassageUnitID(title: focusReference, reference: focusReference, index: 0),
                    collectionID: BuiltInContent.myVersesSetID,
                    order: 1,
                    track: .practiceOnly,
                    verses: verses
                )
            ]
        } else {
            units = groups.enumerated().map { index, group in
                let reference = BuiltInContent.reference(for: group)
                return StudyUnit(
                    id: derivedSharedPassageUnitID(title: focusReference, reference: reference, index: index),
                    collectionID: BuiltInContent.myVersesSetID,
                    order: index + 1,
                    kind: .passage,
                    track: .practiceOnly,
                    title: focusReference,
                    reference: reference,
                    kjvText: group.map(\.kjvText).joined(separator: " "),
                    webText: group.map(\.webText).joined(separator: " "),
                    verseIDs: group.map(\.id)
                )
            }
        }

        startFocusedPractice(for: units, focusReference: focusReference)
    }


    private func handleSharePlanURL(_ components: URLComponents?) {
        guard let items = components?.queryItems else { return }
        guard let bookID = items.first(where: { $0.name == "book" })?.value,
              let sc = items.first(where: { $0.name == "sc" })?.value.flatMap(Int.init),
              let sv = items.first(where: { $0.name == "sv" })?.value.flatMap(Int.init),
              let ec = items.first(where: { $0.name == "ec" })?.value.flatMap(Int.init),
              let ev = items.first(where: { $0.name == "ev" })?.value.flatMap(Int.init)
        else { return }

        let verses = resolveVerseRange(bookID: bookID, startChapter: sc, startVerse: sv, endChapter: ec, endVerse: ev)
        guard verses.count >= 2 else { return }

        createPassageSectionUnits(from: verses)
        selectedTab = .library
    }

    private func resolveVerseRange(bookID: String, startChapter: Int, startVerse: Int, endChapter: Int, endVerse: Int) -> [ScriptureVerse] {
        var verses: [ScriptureVerse] = []
        let chapters = BibleCatalog.chapterNumbers(in: bookID)
        var order = 0
        for chapter in chapters {
            guard chapter >= startChapter, chapter <= endChapter else { continue }
            let lastVerse = BibleCatalog.lastVerseNumber(in: bookID, chapter: chapter)
            let firstV = chapter == startChapter ? startVerse : 1
            let lastV = chapter == endChapter ? endVerse : lastVerse
            for v in firstV...lastV {
                if let verse = BibleCatalog.verse(bookID: bookID, chapter: chapter, verse: v, setID: BuiltInContent.myVersesSetID, order: order) {
                    verses.append(verse)
                    order += 1
                }
            }
        }
        return verses
    }

    private var nextCustomOrder: Int {
        (customStudyUnits.map(\.order).max() ?? 0) + 1
    }

    private func normalizeCustomUnitOrder() {
        customStudyUnits = customStudyUnits
            .sorted { $0.order < $1.order }
            .enumerated()
            .map { index, unit in
                StudyUnit(
                    id: unit.id,
                    collectionID: unit.collectionID,
                    order: index + 1,
                    kind: unit.kind,
                    track: unit.track,
                    title: unit.title,
                    reference: unit.reference,
                    kjvText: unit.kjvText,
                    webText: unit.webText,
                    verseIDs: unit.verseIDs
                )
            }
    }

    private func persistCustomStudyUnits() {
        progressStore.saveCustomStudyUnits(customStudyUnits)
        progressStore.saveCustomVerseIDs(Set(customStudyUnits.compactMap { unit in
            unit.kind == .singleVerse ? unit.verseIDs.first : nil
        }))
    }

    private func resolveVerse(withID verseID: UUID, setID: UUID) -> ScriptureVerse? {
        BuiltInContent.verse(withID: verseID, setID: setID)
    }

    func displayText(for unit: StudyUnit) -> String {
        switch preferredTranslation {
        case .esv:
            return esvTextByReference[unit.reference] ?? unit.kjvText
        case .kjv, .web:
            return unit.text(in: preferredTranslation)
        }
    }

    func displayText(for verse: ScriptureVerse) -> String {
        switch preferredTranslation {
        case .esv:
            return esvTextByReference[verse.reference] ?? verse.kjvText
        case .kjv, .web:
            return verse.text(in: preferredTranslation)
        }
    }

    func displayText(forReference reference: String, verses: [ScriptureVerse]) -> String {
        switch preferredTranslation {
        case .esv:
            return esvTextByReference[reference] ?? verses.map(\.kjvText).joined(separator: " ")
        case .kjv, .web:
            return verses.map { $0.text(in: preferredTranslation) }.joined(separator: " ")
        }
    }

    func verses(for unit: StudyUnit) -> [ScriptureVerse] {
        unit.verseIDs
            .compactMap { resolveVerse(withID: $0, setID: unit.collectionID) }
            .sorted(by: BuiltInContent.sortVerses)
    }

    var userDisplayName: String {
        get {
            progressStore.loadStringPreference("user_display_name") ?? "Me"
        }
        set {
            progressStore.saveStringPreference(newValue, forKey: "user_display_name")
        }
    }

    func progress(for unit: StudyUnit) -> VerseProgress? {
        progressByVerseID[unit.id]
    }

    func reviewEvents(for unitID: UUID) -> [ReviewEvent] {
        recentReviewEvents.filter { $0.unitID == unitID }
    }

    func prefetchPreferredTranslation(for unit: StudyUnit) async {
        guard preferredTranslation == .esv else { return }
        await prefetchESV(reference: unit.reference, estimatedVerseCount: unit.verseIDs.count)
    }

    func prefetchPreferredTranslation(for verse: ScriptureVerse) async {
        guard preferredTranslation == .esv else { return }
        await prefetchESV(reference: verse.reference, estimatedVerseCount: 1)
    }

    func prefetchPreferredTranslation(reference: String, estimatedVerseCount: Int) async {
        guard preferredTranslation == .esv else { return }
        await prefetchESV(reference: reference, estimatedVerseCount: estimatedVerseCount)
    }

    private func prefetchESV(reference: String, estimatedVerseCount: Int) async {
        guard isESVConfigured, esvTextByReference[reference] == nil, !esvInFlightReferences.contains(reference) else {
            return
        }

        esvInFlightReferences.insert(reference)
        defer { esvInFlightReferences.remove(reference) }

        guard var components = URLComponents(string: "https://api.esv.org/v3/passage/text/") else {
            return
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: reference),
            URLQueryItem(name: "include-passage-references", value: "false"),
            URLQueryItem(name: "include-verse-numbers", value: "false"),
            URLQueryItem(name: "include-first-verse-numbers", value: "false"),
            URLQueryItem(name: "include-footnotes", value: "false"),
            URLQueryItem(name: "include-footnote-body", value: "false"),
            URLQueryItem(name: "include-headings", value: "false"),
            URLQueryItem(name: "include-short-copyright", value: "false"),
            URLQueryItem(name: "include-copyright", value: "false"),
            URLQueryItem(name: "indent-using", value: "space"),
            URLQueryItem(name: "indent-paragraphs", value: "0"),
            URLQueryItem(name: "indent-poetry", value: "false"),
            URLQueryItem(name: "line-length", value: "0"),
        ]

        guard let url = components.url, let esvAPIKey else { return }

        var request = URLRequest(url: url)
        request.setValue("Token \(esvAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            let payload = try JSONDecoder().decode(ESVPassageResponse.self, from: data)
            guard let passage = payload.passages.first else { return }
            let normalized = Self.normalizeESVText(passage)
            guard !normalized.isEmpty else { return }
            storeESVText(normalized, for: reference, estimatedVerseCount: estimatedVerseCount)
        } catch {
            return
        }
    }

    private func storeESVText(_ text: String, for reference: String, estimatedVerseCount: Int) {
        if esvTextByReference[reference] == nil {
            esvReferenceOrder.append(reference)
        }

        esvTextByReference[reference] = text
        esvVerseCountByReference[reference] = estimatedVerseCount

        while cachedESVVerseCount > maxCachedESVVerses, let oldestReference = esvReferenceOrder.first {
            esvReferenceOrder.removeFirst()
            esvTextByReference.removeValue(forKey: oldestReference)
            esvVerseCountByReference.removeValue(forKey: oldestReference)
        }
    }

    private var cachedESVVerseCount: Int {
        esvVerseCountByReference.values.reduce(0, +)
    }

    private static func normalizeESVText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveESVAPIKey() -> String? {
        let environment = ProcessInfo.processInfo.environment
        if let key = environment["ESV_API_KEY"], !key.isEmpty {
            return key
        }

        if
            let key = Bundle.main.object(forInfoDictionaryKey: "ESV_API_KEY") as? String,
            !key.isEmpty
        {
            return key
        }

        return nil
    }
}

private struct ESVPassageResponse: Decodable {
    let passages: [String]
}
