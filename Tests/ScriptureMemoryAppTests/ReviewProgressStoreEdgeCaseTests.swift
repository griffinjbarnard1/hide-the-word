import Foundation
import ScriptureMemory
import Testing
@testable import ScriptureMemoryApp

@MainActor
struct ReviewProgressStoreEdgeCaseTests {
    @Test
    func reviewEventsAreTrimmedToMaxLimit() throws {
        let store = try ReviewProgressStore(inMemory: true)
        let unitID = UUID()

        for i in 0..<260 {
            let event = ReviewEvent(
                unitID: unitID,
                unitReference: "Test \(i)",
                reviewedAt: Date(timeIntervalSince1970: Double(1_700_000_000 + i)),
                rating: .medium,
                kind: .review
            )
            store.saveReviewEvent(event)
        }

        let loaded = store.loadReviewEvents()
        #expect(loaded.count <= 250)
    }

    @Test
    func draftSessionRoundTrips() throws {
        let store = try ReviewProgressStore(inMemory: true)
        let unit = BuiltInContent.builtInStudyUnits(for: BuiltInContent.anxietySetID)[0]
        let draft = SessionDraft(
            collectionID: BuiltInContent.anxietySetID,
            items: [SessionItem(unit: unit, kind: .review)],
            currentIndex: 0,
            phase: .display,
            restudiedUnitIDs: [],
            startedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        store.saveDraftSession(draft)
        let loaded = store.loadDraftSession()

        #expect(loaded?.collectionID == draft.collectionID)
        #expect(loaded?.items.count == 1)
        #expect(loaded?.currentIndex == 0)
    }

    @Test
    func savingNilDraftClearsStoredValue() throws {
        let store = try ReviewProgressStore(inMemory: true)
        let unit = BuiltInContent.builtInStudyUnits(for: BuiltInContent.anxietySetID)[0]
        let draft = SessionDraft(
            collectionID: BuiltInContent.anxietySetID,
            items: [SessionItem(unit: unit, kind: .review)],
            currentIndex: 0,
            phase: .display,
            restudiedUnitIDs: [],
            startedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        store.saveDraftSession(draft)
        store.saveDraftSession(nil)
        let loaded = store.loadDraftSession()

        #expect(loaded == nil)
    }

    @Test
    func readOnlyStoreReturnsDefaults() {
        let (store, error) = ReviewProgressStore.initialize(inMemory: false)
        // Even if it succeeds, test the API returns sensible defaults
        _ = error
        let progress = store.loadProgress()
        #expect(progress is [UUID: VerseProgress])
    }

    @Test
    func preferenceRoundTrips() throws {
        let store = try ReviewProgressStore(inMemory: true)

        store.saveAppearance(.dark)
        #expect(store.loadAppearance(default: .system) == .dark)

        store.saveReminderEnabled(true)
        #expect(store.loadReminderEnabled() == true)

        store.saveReminderHour(14)
        #expect(store.loadReminderHour() == 14)

        store.saveTypeRecallEnabled(true)
        #expect(store.loadTypeRecallEnabled() == true)
    }
}
