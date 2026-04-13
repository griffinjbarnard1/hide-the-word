import Foundation
import ScriptureMemory

struct PassageSection: Identifiable, Hashable {
    let id: String
    let title: String
    let reference: String
    let text: String
}

struct PassagePlanSummary: Hashable {
    let sectionCount: Int
    let wordCount: Int
    let sectionLabel: String
    let lengthLabel: String
    let strategyLine: String
}

enum PassageBreakdown {
    static func groupedVerses(for verses: [ScriptureVerse], translation: BibleTranslation) -> [[ScriptureVerse]] {
        let ordered = verses.sorted(by: BuiltInContent.sortVerses)
        guard !ordered.isEmpty else { return [] }

        if ordered.count == 1 {
            return [ordered]
        }

        let targetWordsPerSection = ordered.count >= 12 ? 42 : 30
        var groups: [[ScriptureVerse]] = []
        var current: [ScriptureVerse] = []
        var currentWordCount = 0

        for verse in ordered {
            let verseWords = verse.text(in: translation).split(separator: " ").count
            if !current.isEmpty, currentWordCount + verseWords > targetWordsPerSection {
                groups.append(current)
                current = []
                currentWordCount = 0
            }

            current.append(verse)
            currentWordCount += verseWords
        }

        if !current.isEmpty {
            groups.append(current)
        }

        return groups
    }

    static func sections(for verses: [ScriptureVerse], translation: BibleTranslation) -> [PassageSection] {
        groupedVerses(for: verses, translation: translation).enumerated().map { offset, group in
            let text = group.map { $0.text(in: translation) }.joined(separator: " ")
            return PassageSection(
                id: group.map(\.reference).joined(separator: "|"),
                title: "Section \(offset + 1)",
                reference: reference(for: group),
                text: text
            )
        }
    }

    static func summary(for verses: [ScriptureVerse], translation: BibleTranslation) -> PassagePlanSummary {
        let sections = sections(for: verses, translation: translation)
        let wordCount = verses
            .map { $0.text(in: translation).split(separator: " ").count }
            .reduce(0, +)

        let sectionCount = max(sections.count, 1)
        let sectionLabel = "\(sectionCount) section\(sectionCount == 1 ? "" : "s")"
        let lengthLabel: String
        switch wordCount {
        case ..<18:
            lengthLabel = "Short"
        case ..<45:
            lengthLabel = "Medium"
        case ..<90:
            lengthLabel = "Long"
        default:
            lengthLabel = "Extended"
        }

        let strategyLine: String
        switch sectionCount {
        case 1:
            strategyLine = "This range is compact enough to learn as one unit."
        case 2:
            strategyLine = "This range will be learned in two sections before full recall."
        default:
            strategyLine = "This range will be broken into \(sectionCount) sections so you can hold the flow before full recall."
        }

        return PassagePlanSummary(
            sectionCount: sectionCount,
            wordCount: wordCount,
            sectionLabel: sectionLabel,
            lengthLabel: lengthLabel,
            strategyLine: strategyLine
        )
    }

    private static func reference(for verses: [ScriptureVerse]) -> String {
        guard let first = verses.first, let last = verses.last else { return "Passage" }
        if first.book == last.book {
            if first.chapter == last.chapter {
                if first.verse == last.verse {
                    return first.reference
                }
                return "\(first.book) \(first.chapter):\(first.verse)-\(last.verse)"
            }
            return "\(first.book) \(first.chapter):\(first.verse)-\(last.chapter):\(last.verse)"
        }

        return "\(first.reference) - \(last.reference)"
    }
}
