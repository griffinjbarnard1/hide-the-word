import Foundation

public enum BuiltInContent {
    public static let faithSetID = UUID(uuidString: "1B6E0A6B-5E90-4C86-A2E0-3E06A31F03E1")!
    public static let anxietySetID = UUID(uuidString: "22CF8868-8A73-42E5-8971-0C58D4A144F2")!
    public static let gospelSetID = UUID(uuidString: "6450F4A7-87CC-452E-A65D-BABAA9452C2C")!
    public static let myVersesSetID = UUID(uuidString: "A1C3A642-28C4-49B6-A4CF-38D707AF36A8")!

    public static let hebrews11Verse1ID = UUID(uuidString: "E90F715F-18F3-4E46-89B8-5A3A2CF58D30")!
    public static let proverbs3Verse5ID = UUID(uuidString: "7E23E6A7-2628-4B8C-9742-7E2F69AA73A3")!
    public static let philippians4Verse6ID = UUID(uuidString: "93DD8943-2280-4375-B89A-5631B4BD373E")!
    public static let firstPeter5Verse7ID = UUID(uuidString: "F5655F34-CF72-4A95-B7D0-E8FEF66F88B3")!
    public static let john3Verse16ID = UUID(uuidString: "E2F1E8B0-2D6B-43A7-A5C5-55E9B7FEA414")!
    public static let ephesians2Verse8ID = UUID(uuidString: "6E786405-3618-421A-94DD-D13518197AFD")!

    public static let verseSets: [VerseSet] = [
        VerseSet(
            id: faithSetID,
            title: "Faith",
            summary: "Foundational verses on trust, dependence, and confidence in God.",
            systemImageName: "shield.lefthalf.filled"
        ),
        VerseSet(
            id: anxietySetID,
            title: "Anxiety",
            summary: "Verses for prayer, peace, and steadiness under pressure.",
            systemImageName: "wind"
        ),
        VerseSet(
            id: gospelSetID,
            title: "Core Gospel Verses",
            summary: "Short set of central passages on salvation and new life.",
            systemImageName: "cross.case"
        ),
        VerseSet(
            id: myVersesSetID,
            title: "My Verses",
            summary: "A custom collection you build from the verse library.",
            systemImageName: "bookmark",
            isCustom: true
        )
    ]

    public static let verses: [ScriptureVerse] = [
        ScriptureVerse(
            id: hebrews11Verse1ID,
            setID: faithSetID,
            order: 1,
            bookID: "hebrews",
            bookNumber: 58,
            book: "Hebrews",
            chapter: 11,
            verse: 1,
            kjvText: "Now faith is the substance of things hoped for, the evidence of things not seen.",
            webText: "Now faith is assurance of things hoped for, proof of things not seen."
        ),
        ScriptureVerse(
            id: proverbs3Verse5ID,
            setID: faithSetID,
            order: 2,
            bookID: "proverbs",
            bookNumber: 20,
            book: "Proverbs",
            chapter: 3,
            verse: 5,
            kjvText: "Trust in the Lord with all thine heart; and lean not unto thine own understanding.",
            webText: "Trust in Yahweh with all your heart, and don't lean on your own understanding."
        ),
        ScriptureVerse(
            id: philippians4Verse6ID,
            setID: anxietySetID,
            order: 1,
            bookID: "philippians",
            bookNumber: 50,
            book: "Philippians",
            chapter: 4,
            verse: 6,
            kjvText: "Be anxious for nothing, but in everything by prayer and supplication with thanksgiving let your requests be made known to God.",
            webText: "In nothing be anxious, but in everything, by prayer and petition with thanksgiving, let your requests be made known to God."
        ),
        ScriptureVerse(
            id: firstPeter5Verse7ID,
            setID: anxietySetID,
            order: 2,
            bookID: "1peter",
            bookNumber: 60,
            book: "1 Peter",
            chapter: 5,
            verse: 7,
            kjvText: "Casting all your care upon him; for he careth for you.",
            webText: "Casting all your worries on him, because he cares for you."
        ),
        ScriptureVerse(
            id: john3Verse16ID,
            setID: gospelSetID,
            order: 1,
            bookID: "john",
            bookNumber: 43,
            book: "John",
            chapter: 3,
            verse: 16,
            kjvText: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
            webText: "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life."
        ),
        ScriptureVerse(
            id: ephesians2Verse8ID,
            setID: gospelSetID,
            order: 2,
            bookID: "ephesians",
            bookNumber: 49,
            book: "Ephesians",
            chapter: 2,
            verse: 8,
            kjvText: "For by grace are ye saved through faith; and that not of yourselves: it is the gift of God.",
            webText: "For by grace you have been saved through faith, and that not of yourselves; it is the gift of God."
        )
    ]

    public static let builtInStudyUnits: [StudyUnit] = verses.map { verse in
        StudyUnit(
            id: verse.id,
            collectionID: verse.setID,
            order: verse.order,
            kind: .singleVerse,
            track: .scheduled,
            title: verse.reference,
            reference: verse.reference,
            kjvText: verse.kjvText,
            webText: verse.webText,
            verseIDs: [verse.id]
        )
    }

    public static func collection(for id: UUID) -> VerseSet {
        verseSets.first(where: { $0.id == id }) ?? verseSets[0]
    }

    public static func builtInStudyUnits(for collectionID: UUID) -> [StudyUnit] {
        builtInStudyUnits
            .filter { $0.collectionID == collectionID }
            .sorted { $0.order < $1.order }
    }

    public static func fixedVerseID(book: String, chapter: Int, verse: Int) -> UUID? {
        switch (book, chapter, verse) {
        case ("Hebrews", 11, 1):
            return hebrews11Verse1ID
        case ("Proverbs", 3, 5):
            return proverbs3Verse5ID
        case ("Philippians", 4, 6):
            return philippians4Verse6ID
        case ("1 Peter", 5, 7):
            return firstPeter5Verse7ID
        case ("John", 3, 16):
            return john3Verse16ID
        case ("Ephesians", 2, 8):
            return ephesians2Verse8ID
        default:
            return nil
        }
    }

    public static func verse(withID id: UUID, setID: UUID = myVersesSetID) -> ScriptureVerse? {
        verses.first(where: { $0.id == id }) ?? BibleCatalog.verse(withID: id, setID: setID)
    }

    public static func studyUnitForSingleVerse(_ verse: ScriptureVerse, collectionID: UUID, order: Int) -> StudyUnit {
        StudyUnit(
            id: verse.id,
            collectionID: collectionID,
            order: order,
            kind: .singleVerse,
            track: .scheduled,
            title: verse.reference,
            reference: verse.reference,
            kjvText: verse.kjvText,
            webText: verse.webText,
            verseIDs: [verse.id]
        )
    }

    public static func passageStudyUnit(
        id: UUID,
        collectionID: UUID,
        order: Int,
        track: StudyUnitTrack = .scheduled,
        verses selectedVerses: [ScriptureVerse]
    ) -> StudyUnit {
        let orderedVerses = selectedVerses.sorted(by: sortVerses)
        let kjvText = orderedVerses.map(\.kjvText).joined(separator: " ")
        let webText = orderedVerses.map(\.webText).joined(separator: " ")

        return StudyUnit(
            id: id,
            collectionID: collectionID,
            order: order,
            kind: .passage,
            track: track,
            title: passageTitle(for: orderedVerses),
            reference: passageReference(for: orderedVerses),
            kjvText: kjvText,
            webText: webText,
            verseIDs: orderedVerses.map(\.id)
        )
    }

    public static func reference(for verses: [ScriptureVerse]) -> String {
        passageReference(for: verses.sorted(by: sortVerses))
    }

    public static func isCustomCollection(_ id: UUID) -> Bool {
        id == myVersesSetID
    }

    public static func sortVerses(lhs: ScriptureVerse, rhs: ScriptureVerse) -> Bool {
        let lhsBookNumber = lhs.bookNumber == 0 ? (BibleCatalog.bookNumber(for: lhs.book) ?? Int.max) : lhs.bookNumber
        let rhsBookNumber = rhs.bookNumber == 0 ? (BibleCatalog.bookNumber(for: rhs.book) ?? Int.max) : rhs.bookNumber

        if lhsBookNumber == rhsBookNumber {
            if lhs.chapter == rhs.chapter {
                return lhs.verse < rhs.verse
            }
            return lhs.chapter < rhs.chapter
        }

        return lhsBookNumber < rhsBookNumber
    }

    private static func passageTitle(for verses: [ScriptureVerse]) -> String {
        passageReference(for: verses)
    }

    private static func passageReference(for verses: [ScriptureVerse]) -> String {
        guard let first = verses.first, let last = verses.last else { return "Passage" }
        if verses.count == 1 {
            return first.reference
        }

        if first.book == last.book {
            if first.chapter == last.chapter {
                return "\(first.book) \(first.chapter):\(first.verse)-\(last.verse)"
            }
            return "\(first.book) \(first.chapter):\(first.verse)-\(last.chapter):\(last.verse)"
        }

        return "\(first.reference) + \(last.reference)"
    }
}
