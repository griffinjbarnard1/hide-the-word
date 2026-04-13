import Foundation
import Testing
@testable import ScriptureMemory

struct PlanDayGeneratorTests {
    @Test
    func emptyReferencesProducesNoDays() {
        let days = PlanDayGenerator.generateDays(from: [])
        #expect(days.isEmpty)
    }

    @Test
    func singleVerseProducesOneLearnDayAndNoRecallDay() {
        let refs = [VerseReference(bookID: "john", chapter: 3, verse: 16)]
        let days = PlanDayGenerator.generateDays(from: refs)

        #expect(days.count == 1)
        #expect(days[0].goal == .learnNew)
        #expect(days[0].dayNumber == 1)
        #expect(days[0].title == "john 3:16")
    }

    @Test
    func twoVersesProducesOneLearnDayAndNoRecallDay() {
        let refs = [
            VerseReference(bookID: "john", chapter: 3, verse: 16),
            VerseReference(bookID: "john", chapter: 3, verse: 17),
        ]
        let days = PlanDayGenerator.generateDays(from: refs)

        #expect(days.count == 1)
        #expect(days[0].goal == .learnNew)
        #expect(days[0].verseReferences.count == 2)
    }

    @Test
    func threeVersesProducesRecallDay() {
        let refs = (1...3).map { VerseReference(bookID: "rom", chapter: 8, verse: $0) }
        let days = PlanDayGenerator.generateDays(from: refs)

        #expect(days.last?.goal == .fullRecall)
        #expect(days.last?.verseReferences.count == 3)
    }

    @Test
    func reviewDayInsertedEveryThreeLearnDays() {
        let refs = (1...8).map { VerseReference(bookID: "ps", chapter: 23, verse: $0) }
        let days = PlanDayGenerator.generateDays(from: refs)

        let reviewDays = days.filter { $0.goal == .reviewOnly }
        #expect(reviewDays.count >= 1)
        #expect(reviewDays.allSatisfy { $0.verseReferences.isEmpty })
    }

    @Test
    func dayNumbersAreSequential() {
        let refs = (1...6).map { VerseReference(bookID: "gen", chapter: 1, verse: $0) }
        let days = PlanDayGenerator.generateDays(from: refs)

        for (index, day) in days.enumerated() {
            #expect(day.dayNumber == index + 1)
        }
    }
}
