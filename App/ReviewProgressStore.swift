import Foundation
import ScriptureMemory
import SwiftData

@Model
final class StoredVerseProgress {
    @Attribute(.unique) var verseID: UUID
    var reviewCount: Int
    var intervalDays: Int
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    var lastRatingRawValue: String?

    init(
        verseID: UUID,
        reviewCount: Int = 0,
        intervalDays: Int = 0,
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        lastRatingRawValue: String? = nil
    ) {
        self.verseID = verseID
        self.reviewCount = reviewCount
        self.intervalDays = intervalDays
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.lastRatingRawValue = lastRatingRawValue
    }
}

@Model
final class StoredAppPreference {
    @Attribute(.unique) var key: String
    var value: String

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

@Model
final class StoredCustomVerseSelection {
    @Attribute(.unique) var verseID: UUID

    init(verseID: UUID) {
        self.verseID = verseID
    }
}

@Model
final class StoredReviewEvent {
    var unitID: UUID
    var unitReference: String
    var reviewedAt: Date
    var ratingRawValue: String
    var kindRawValue: String

    init(
        unitID: UUID,
        unitReference: String,
        reviewedAt: Date,
        ratingRawValue: String,
        kindRawValue: String
    ) {
        self.unitID = unitID
        self.unitReference = unitReference
        self.reviewedAt = reviewedAt
        self.ratingRawValue = ratingRawValue
        self.kindRawValue = kindRawValue
    }
}

struct ReviewEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let unitID: UUID
    let unitReference: String
    let reviewedAt: Date
    let rating: ReviewRating
    let kind: SessionItemKind

    init(unitID: UUID, unitReference: String, reviewedAt: Date, rating: ReviewRating, kind: SessionItemKind) {
        self.id = "\(unitID.uuidString)|\(reviewedAt.timeIntervalSince1970)"
        self.unitID = unitID
        self.unitReference = unitReference
        self.reviewedAt = reviewedAt
        self.rating = rating
        self.kind = kind
    }
}

@MainActor
final class ReviewProgressStore {
    private enum PreferenceKey {
        static let selectedCollectionID = "selected_collection_id"
        static let preferredTranslation = "preferred_translation"
        static let sessionSizePreset = "session_size_preset"
        static let customStudyUnits = "custom_study_units"
        static let draftSession = "draft_session"
        static let appearance = "appearance"
        static let reminderEnabled = "reminder_enabled"
        static let reminderHour = "reminder_hour"
        static let reminderMinute = "reminder_minute"
        static let hasCompletedOnboarding = "has_completed_onboarding"
        static let typeRecallEnabled = "type_recall_enabled"
    }

    let container: ModelContainer
    let context: ModelContext

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(
            schema: Schema([StoredVerseProgress.self, StoredAppPreference.self, StoredCustomVerseSelection.self, StoredReviewEvent.self]),
            isStoredInMemoryOnly: inMemory
        )
        do {
            container = try ModelContainer(
                for: StoredVerseProgress.self,
                StoredAppPreference.self,
                StoredCustomVerseSelection.self,
                StoredReviewEvent.self,
                configurations: configuration
            )
            context = ModelContext(container)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    func loadProgress() -> [UUID: VerseProgress] {
        let descriptor = FetchDescriptor<StoredVerseProgress>(
            sortBy: [SortDescriptor(\.nextReviewAt), SortDescriptor(\.verseID)]
        )

        let records = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: records.map { record in
            (
                record.verseID,
                VerseProgress(
                    verseID: record.verseID,
                    reviewCount: record.reviewCount,
                    intervalDays: record.intervalDays,
                    lastReviewedAt: record.lastReviewedAt,
                    nextReviewAt: record.nextReviewAt,
                    lastRating: record.lastRatingRawValue.flatMap(ReviewRating.init(rawValue:))
                )
            )
        })
    }

    func save(_ progress: VerseProgress) {
        let descriptor = FetchDescriptor<StoredVerseProgress>(
            predicate: #Predicate { $0.verseID == progress.verseID }
        )

        let record = (try? context.fetch(descriptor).first) ?? nil
        let target = record ?? StoredVerseProgress(verseID: progress.verseID)
        target.reviewCount = progress.reviewCount
        target.intervalDays = progress.intervalDays
        target.lastReviewedAt = progress.lastReviewedAt
        target.nextReviewAt = progress.nextReviewAt
        target.lastRatingRawValue = progress.lastRating?.rawValue

        if record == nil {
            context.insert(target)
        }

        try? context.save()
    }

    func loadSelectedCollectionID(default defaultValue: UUID) -> UUID {
        guard
            let rawValue = value(forPreferenceKey: PreferenceKey.selectedCollectionID),
            let collectionID = UUID(uuidString: rawValue)
        else {
            return defaultValue
        }

        return collectionID
    }

    func saveSelectedCollectionID(_ collectionID: UUID) {
        savePreferenceValue(collectionID.uuidString, forKey: PreferenceKey.selectedCollectionID)
    }

    func loadPreferredTranslation(default defaultValue: BibleTranslation) -> BibleTranslation {
        guard
            let rawValue = value(forPreferenceKey: PreferenceKey.preferredTranslation),
            let translation = BibleTranslation(rawValue: rawValue)
        else {
            return defaultValue
        }

        return translation
    }

    func savePreferredTranslation(_ translation: BibleTranslation) {
        savePreferenceValue(translation.rawValue, forKey: PreferenceKey.preferredTranslation)
    }

    func loadSessionSizePreset(default defaultValue: SessionSizePreset) -> SessionSizePreset {
        guard
            let rawValue = value(forPreferenceKey: PreferenceKey.sessionSizePreset),
            let preset = SessionSizePreset(rawValue: rawValue)
        else {
            return defaultValue
        }

        return preset
    }

    func saveSessionSizePreset(_ preset: SessionSizePreset) {
        savePreferenceValue(preset.rawValue, forKey: PreferenceKey.sessionSizePreset)
    }

    func loadAppearance(default defaultValue: AppAppearance) -> AppAppearance {
        guard
            let rawValue = value(forPreferenceKey: PreferenceKey.appearance),
            let appearance = AppAppearance(rawValue: rawValue)
        else {
            return defaultValue
        }
        return appearance
    }

    func saveAppearance(_ appearance: AppAppearance) {
        savePreferenceValue(appearance.rawValue, forKey: PreferenceKey.appearance)
    }

    func loadHasCompletedOnboarding() -> Bool {
        value(forPreferenceKey: PreferenceKey.hasCompletedOnboarding) == "true"
    }

    func saveHasCompletedOnboarding() {
        savePreferenceValue("true", forKey: PreferenceKey.hasCompletedOnboarding)
    }

    func loadReminderEnabled() -> Bool {
        value(forPreferenceKey: PreferenceKey.reminderEnabled) == "true"
    }

    func saveReminderEnabled(_ enabled: Bool) {
        savePreferenceValue(enabled ? "true" : "false", forKey: PreferenceKey.reminderEnabled)
    }

    func loadReminderHour() -> Int {
        Int(value(forPreferenceKey: PreferenceKey.reminderHour) ?? "") ?? 8
    }

    func saveReminderHour(_ hour: Int) {
        savePreferenceValue("\(hour)", forKey: PreferenceKey.reminderHour)
    }

    func loadReminderMinute() -> Int {
        Int(value(forPreferenceKey: PreferenceKey.reminderMinute) ?? "") ?? 0
    }

    func saveReminderMinute(_ minute: Int) {
        savePreferenceValue("\(minute)", forKey: PreferenceKey.reminderMinute)
    }

    func loadTypeRecallEnabled() -> Bool {
        value(forPreferenceKey: PreferenceKey.typeRecallEnabled) == "true"
    }

    func saveTypeRecallEnabled(_ enabled: Bool) {
        savePreferenceValue(enabled ? "true" : "false", forKey: PreferenceKey.typeRecallEnabled)
    }

    func loadStringPreference(_ key: String) -> String? {
        value(forPreferenceKey: key)
    }

    func saveStringPreference(_ value: String, forKey key: String) {
        savePreferenceValue(value, forKey: key)
    }

    func loadIntPreference(_ key: String, default defaultValue: Int) -> Int {
        guard let raw = value(forPreferenceKey: key) else { return defaultValue }
        return Int(raw) ?? defaultValue
    }

    func saveIntPreference(_ value: Int, forKey key: String) {
        savePreferenceValue(String(value), forKey: key)
    }

    func loadDatePreference(_ key: String) -> Date? {
        guard let raw = value(forPreferenceKey: key), let interval = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func saveDatePreference(_ date: Date, forKey key: String) {
        savePreferenceValue(String(date.timeIntervalSince1970), forKey: key)
    }

    func loadCustomStudyUnits() -> [StudyUnit] {
        loadCodableValue(forKey: PreferenceKey.customStudyUnits) ?? []
    }

    func saveCustomStudyUnits(_ units: [StudyUnit]) {
        saveCodableValue(units, forKey: PreferenceKey.customStudyUnits)
    }

    func loadDraftSession() -> SessionDraft? {
        loadCodableValue(forKey: PreferenceKey.draftSession)
    }

    func saveDraftSession(_ draft: SessionDraft?) {
        if let draft {
            saveCodableValue(draft, forKey: PreferenceKey.draftSession)
        } else {
            removePreferenceValue(forKey: PreferenceKey.draftSession)
        }
    }

    func loadCustomVerseIDs() -> Set<UUID> {
        let descriptor = FetchDescriptor<StoredCustomVerseSelection>(
            sortBy: [SortDescriptor(\.verseID)]
        )

        let records = (try? context.fetch(descriptor)) ?? []
        return Set(records.map(\.verseID))
    }

    func saveCustomVerseIDs(_ verseIDs: Set<UUID>) {
        let descriptor = FetchDescriptor<StoredCustomVerseSelection>()
        let existingRecords = (try? context.fetch(descriptor)) ?? []
        let existingIDs = Set(existingRecords.map(\.verseID))

        for record in existingRecords where !verseIDs.contains(record.verseID) {
            context.delete(record)
        }

        for verseID in verseIDs where !existingIDs.contains(verseID) {
            context.insert(StoredCustomVerseSelection(verseID: verseID))
        }

        try? context.save()
    }

    func loadReviewEvents(limit: Int? = nil) -> [ReviewEvent] {
        var descriptor = FetchDescriptor<StoredReviewEvent>(
            sortBy: [SortDescriptor(\.reviewedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { record in
            guard
                let rating = ReviewRating(rawValue: record.ratingRawValue),
                let kind = SessionItemKind(rawValue: record.kindRawValue)
            else {
                return nil
            }

            return ReviewEvent(
                unitID: record.unitID,
                unitReference: record.unitReference,
                reviewedAt: record.reviewedAt,
                rating: rating,
                kind: kind
            )
        }
    }

    func saveReviewEvent(_ event: ReviewEvent) {
        let record = StoredReviewEvent(
            unitID: event.unitID,
            unitReference: event.unitReference,
            reviewedAt: event.reviewedAt,
            ratingRawValue: event.rating.rawValue,
            kindRawValue: event.kind.rawValue
        )
        context.insert(record)
        trimReviewEventsIfNeeded(maxEvents: 250)
        try? context.save()
    }

    func loadCodableValue<T: Decodable>(forKey key: String) -> T? {
        guard
            let rawValue = value(forPreferenceKey: key),
            let data = rawValue.data(using: .utf8)
        else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    func saveCodableValue<T: Encodable>(_ value: T, forKey key: String) {
        guard
            let data = try? JSONEncoder().encode(value),
            let rawValue = String(data: data, encoding: .utf8)
        else {
            return
        }

        savePreferenceValue(rawValue, forKey: key)
    }

    private func value(forPreferenceKey key: String) -> String? {
        let descriptor = FetchDescriptor<StoredAppPreference>(
            predicate: #Predicate { $0.key == key }
        )
        return try? context.fetch(descriptor).first?.value
    }

    private func removePreferenceValue(forKey key: String) {
        let descriptor = FetchDescriptor<StoredAppPreference>(
            predicate: #Predicate { $0.key == key }
        )

        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
    }

    private func savePreferenceValue(_ value: String, forKey key: String) {
        let descriptor = FetchDescriptor<StoredAppPreference>(
            predicate: #Predicate { $0.key == key }
        )

        let record = (try? context.fetch(descriptor).first) ?? nil
        let target = record ?? StoredAppPreference(key: key, value: value)
        target.value = value

        if record == nil {
            context.insert(target)
        }

        try? context.save()
    }

    private func trimReviewEventsIfNeeded(maxEvents: Int) {
        let descriptor = FetchDescriptor<StoredReviewEvent>(
            sortBy: [SortDescriptor(\.reviewedAt, order: .reverse)]
        )

        let records = (try? context.fetch(descriptor)) ?? []
        guard records.count > maxEvents else { return }

        for record in records.dropFirst(maxEvents) {
            context.delete(record)
        }
    }
}
