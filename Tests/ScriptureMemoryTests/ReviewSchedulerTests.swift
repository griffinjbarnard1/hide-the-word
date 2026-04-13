import Foundation
import Testing
@testable import ScriptureMemory

struct ReviewSchedulerTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let baseDate = Date(timeIntervalSince1970: 1_710_000_000)

    @Test
    func buildsPlanWithDueReviewsFirstAndOneNewVerse() {
        let setID = BuiltInContent.anxietySetID
        let units = BuiltInContent.builtInStudyUnits(for: setID)
        let dueUnit = units[0]
        let newUnit = units[1]

        let progress = [
            dueUnit.id: VerseProgress(
                verseID: dueUnit.id,
                reviewCount: 1,
                intervalDays: 2,
                lastReviewedAt: calendar.date(byAdding: .day, value: -3, to: baseDate),
                nextReviewAt: calendar.date(byAdding: .day, value: -1, to: baseDate),
                lastRating: .medium
            )
        ]

        let plan = ReviewScheduler.buildPlan(
            units: units,
            progressByUnitID: progress,
            on: baseDate
        )

        #expect(plan.items.count == 2)
        #expect(plan.items[0].kind == .review)
        #expect(plan.items[0].unit.id == dueUnit.id)
        #expect(plan.items[1].kind == .newVerse)
        #expect(plan.items[1].unit.id == newUnit.id)
        #expect(plan.dueReviewCount == 1)
    }

    @Test
    func doesNotIntroduceNewVerseWhenSessionIsAtCapacity() {
        let setID = BuiltInContent.gospelSetID
        let units = BuiltInContent.builtInStudyUnits(for: setID)

        let progress = Dictionary(uniqueKeysWithValues: units.map { unit in
            (
                unit.id,
                VerseProgress(
                    verseID: unit.id,
                    reviewCount: 3,
                    intervalDays: 4,
                    lastReviewedAt: calendar.date(byAdding: .day, value: -7, to: baseDate),
                    nextReviewAt: calendar.date(byAdding: .day, value: -1, to: baseDate),
                    lastRating: .easy
                )
            )
        })

        let plan = ReviewScheduler.buildPlan(
            units: units,
            progressByUnitID: progress,
            on: baseDate,
            config: SessionConfig(maxReviewItems: 2, maxTotalItems: 2)
        )

        #expect(plan.items.count == 2)
        #expect(plan.items.allSatisfy { $0.kind == .review })
    }

    @Test
    func fallsBackToOneLightReviewWhenNothingIsDueAndNothingIsNew() {
        let units = BuiltInContent.builtInStudyUnits(for: BuiltInContent.anxietySetID)
        let progress = Dictionary(uniqueKeysWithValues: units.enumerated().map { index, unit in
            (
                unit.id,
                VerseProgress(
                    verseID: unit.id,
                    reviewCount: 2,
                    intervalDays: 7,
                    lastReviewedAt: calendar.date(byAdding: .day, value: -(10 + index), to: baseDate),
                    nextReviewAt: calendar.date(byAdding: .day, value: 3 + index, to: baseDate),
                    lastRating: .medium
                )
            )
        })

        let plan = ReviewScheduler.buildPlan(
            units: units,
            progressByUnitID: progress,
            on: baseDate
        )

        #expect(plan.items.count == 1)
        #expect(plan.items[0].kind == .review)
        #expect(plan.items[0].unit.id == units[0].id)
        #expect(plan.dueReviewCount == 0)
    }

    @Test
    func firstReviewIntervalsMatchProductExpectations() {
        let unit = BuiltInContent.builtInStudyUnits[0]

        let hard = ReviewScheduler.apply(rating: .hard, to: unit, existing: nil, reviewedAt: baseDate, calendar: calendar)
        let medium = ReviewScheduler.apply(rating: .medium, to: unit, existing: nil, reviewedAt: baseDate, calendar: calendar)
        let easy = ReviewScheduler.apply(rating: .easy, to: unit, existing: nil, reviewedAt: baseDate, calendar: calendar)

        #expect(hard.intervalDays == 1)
        #expect(medium.intervalDays == 2)
        #expect(easy.intervalDays == 4)
    }

    @Test
    func hardRatingCompressesIntervalAfterMissedConfidence() {
        let unit = BuiltInContent.builtInStudyUnits[0]
        let existing = VerseProgress(
            verseID: unit.id,
            reviewCount: 4,
            intervalDays: 8,
            lastReviewedAt: calendar.date(byAdding: .day, value: -9, to: baseDate),
            nextReviewAt: calendar.date(byAdding: .day, value: -1, to: baseDate),
            lastRating: .easy
        )

        let updated = ReviewScheduler.apply(
            rating: .hard,
            to: unit,
            existing: existing,
            reviewedAt: baseDate,
            calendar: calendar
        )

        #expect(updated.intervalDays == 4)
        #expect(updated.reviewCount == 5)
        #expect(updated.lastRating == .hard)
    }

    @Test
    func routeBuilderProducesStableDeepLinks() {
        #expect(AppRouteBuilder.url(for: .todaySession).absoluteString == "scripturememory://session/today")
        #expect(AppRouteBuilder.url(for: .verseSets).absoluteString == "scripturememory://sets")
        #expect(AppRouteBuilder.url(for: .journey).absoluteString == "scripturememory://journey")
        #expect(
            AppRouteBuilder.url(for: .todaySession, setID: BuiltInContent.faithSetID).absoluteString
                == "scripturememory://session/today?setID=1B6E0A6B-5E90-4C86-A2E0-3E06A31F03E1"
        )
    }

    @Test
    func bibleCatalogReusesFixedIDsForKnownBuiltInVerses() {
        let verse = BibleCatalog.verse(
            bookID: "john",
            chapter: 3,
            verse: 16,
            setID: BuiltInContent.myVersesSetID
        )

        #expect(verse?.id == BuiltInContent.john3Verse16ID)
        #expect(verse?.reference == "John 3:16")
    }



    @Test
    func bibleCatalogReportsMissingResourceAsTypedError() {
        do {
            _ = try BibleCatalog._loadStoreForTesting(
                resourceURLProvider: { nil },
                fileLoader: { _ in Data() }
            )
            Issue.record("Expected missing-resource error")
        } catch let error as BibleCatalogError {
            if case .missingResource = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected BibleCatalogError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test
    func bibleCatalogReportsCorruptedPayloadAsTypedError() {
        do {
            _ = try BibleCatalog._loadStoreForTesting(
                resourceURLProvider: { URL(filePath: "/tmp/not-used.json") },
                fileLoader: { _ in Data("{bad json".utf8) }
            )
            Issue.record("Expected decode failure error")
        } catch let error as BibleCatalogError {
            if case .decodeFailed = error {
                #expect(Bool(true))
            } else {
                Issue.record("Unexpected BibleCatalogError: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
    @Test
    func bibleCatalogSupportsCrossChapterRanges() {
        let verses = BibleCatalog.verseRange(
            bookID: "1peter",
            startChapter: 1,
            startVerse: 1,
            endChapter: 2,
            endVerse: 3,
            setID: BuiltInContent.myVersesSetID
        )

        #expect(verses.count > 3)
        #expect(verses.first?.reference == "1 Peter 1:1")
        #expect(verses.last?.reference == "1 Peter 2:3")
    }
}
