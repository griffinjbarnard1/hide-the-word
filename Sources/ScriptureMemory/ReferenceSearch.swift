import Foundation

/// A Bible reference resolved from free-form search text like
/// "John 3:16", "1 jn 1:9", "ps 23", or "phil 4:13-14".
public struct ReferenceSearchMatch: Equatable, Sendable {
    public let bookID: String
    public let bookName: String
    public let chapter: Int
    public let startVerse: Int?
    public let endVerse: Int?

    public init(bookID: String, bookName: String, chapter: Int, startVerse: Int?, endVerse: Int?) {
        self.bookID = bookID
        self.bookName = bookName
        self.chapter = chapter
        self.startVerse = startVerse
        self.endVerse = endVerse
    }

    public var displayReference: String {
        guard let startVerse else {
            return "\(bookName) \(chapter)"
        }
        if let endVerse {
            return "\(bookName) \(chapter):\(startVerse)-\(endVerse)"
        }
        return "\(bookName) \(chapter):\(startVerse)"
    }
}

/// Turns free-form text into a Bible reference so people can type a verse
/// the way they say it instead of scrolling through pickers.
public enum ReferenceSearch {
    /// Shorthand that plain prefix matching can't resolve (e.g. "jn"),
    /// or that should win over the first prefix match in canonical order.
    private static let abbreviations: [String: String] = [
        "gn": "genesis",
        "ex": "exodus",
        "lv": "leviticus",
        "nm": "numbers",
        "dt": "deuteronomy",
        "jsh": "joshua",
        "jdg": "judges",
        "jgs": "judges",
        "1 sm": "1 samuel",
        "2 sm": "2 samuel",
        "1 kgs": "1 kings",
        "2 kgs": "2 kings",
        "1 chr": "1 chronicles",
        "2 chr": "2 chronicles",
        "neh": "nehemiah",
        "ps": "psalms",
        "psa": "psalms",
        "psalm": "psalms",
        "pr": "proverbs",
        "prv": "proverbs",
        "eccl": "ecclesiastes",
        "sg": "song of solomon",
        "sos": "song of solomon",
        "song": "song of solomon",
        "is": "isaiah",
        "jer": "jeremiah",
        "lam": "lamentations",
        "ezk": "ezekiel",
        "dn": "daniel",
        "hos": "hosea",
        "ob": "obadiah",
        "mic": "micah",
        "nah": "nahum",
        "hab": "habakkuk",
        "zep": "zephaniah",
        "hag": "haggai",
        "zec": "zechariah",
        "mal": "malachi",
        "mt": "matthew",
        "mk": "mark",
        "lk": "luke",
        "jn": "john",
        "rom": "romans",
        "1 cor": "1 corinthians",
        "2 cor": "2 corinthians",
        "gal": "galatians",
        "eph": "ephesians",
        "phil": "philippians",
        "php": "philippians",
        "col": "colossians",
        "1 th": "1 thessalonians",
        "2 th": "2 thessalonians",
        "1 thess": "1 thessalonians",
        "2 thess": "2 thessalonians",
        "1 tim": "1 timothy",
        "2 tim": "2 timothy",
        "tit": "titus",
        "phlm": "philemon",
        "philem": "philemon",
        "heb": "hebrews",
        "jas": "james",
        "1 pt": "1 peter",
        "2 pt": "2 peter",
        "1 jn": "1 john",
        "2 jn": "2 john",
        "3 jn": "3 john",
        "rv": "revelation",
        "rev": "revelation",
    ]

    public static func match(
        _ query: String,
        books: [BibleBookSummary] = BibleCatalog.books
    ) -> ReferenceSearchMatch? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let (bookKey, numbers) = split(trimmed)
        guard bookKey.count >= 2, let book = resolveBook(bookKey, books: books) else {
            return nil
        }

        let chapter = min(max(numbers.first ?? 1, 1), max(book.chapterCount, 1))
        var startVerse: Int? = numbers.count > 1 ? max(numbers[1], 1) : nil
        var endVerse: Int? = numbers.count > 2 ? max(numbers[2], 1) : nil

        if let start = startVerse, let end = endVerse {
            if end < start {
                startVerse = end
                endVerse = start
            }
            if startVerse == endVerse {
                endVerse = nil
            }
        }

        return ReferenceSearchMatch(
            bookID: book.id,
            bookName: book.name,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse
        )
    }

    /// Splits text into a lowercase book key ("1 john") and the trailing
    /// chapter/verse numbers ([3, 16, 18] for "3:16-18"). A digit run that
    /// appears before any letters is treated as a numbered-book prefix.
    private static func split(_ query: String) -> (bookKey: String, numbers: [Int]) {
        var bookParts: [String] = []
        var numbers: [Int] = []
        var letters = ""
        var digits = ""
        var sawLetters = false

        func flushLetters() {
            guard !letters.isEmpty else { return }
            bookParts.append(letters)
            letters = ""
        }

        func flushDigits() {
            guard !digits.isEmpty else { return }
            if !sawLetters {
                bookParts.append(digits)
            } else if let value = Int(digits) {
                numbers.append(value)
            }
            digits = ""
        }

        for character in query.lowercased() {
            if character.isLetter {
                flushDigits()
                letters.append(character)
                sawLetters = true
            } else if character.isNumber {
                flushLetters()
                digits.append(character)
            } else {
                flushLetters()
                flushDigits()
            }
        }
        flushLetters()
        flushDigits()

        return (bookParts.joined(separator: " "), numbers)
    }

    private static func resolveBook(_ key: String, books: [BibleBookSummary]) -> BibleBookSummary? {
        if let fullName = abbreviations[key],
           let book = books.first(where: { $0.name.lowercased() == fullName }) {
            return book
        }
        if let book = books.first(where: { $0.name.lowercased() == key }) {
            return book
        }
        return books.first(where: { $0.name.lowercased().hasPrefix(key) })
    }
}
