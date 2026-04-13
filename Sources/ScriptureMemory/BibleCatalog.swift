import CryptoKit
import Foundation
import os

public struct BibleBookSummary: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let number: Int
    public let name: String
    public let chapterCount: Int

    public init(id: String, number: Int, name: String, chapterCount: Int) {
        self.id = id
        self.number = number
        self.name = name
        self.chapterCount = chapterCount
    }
}

public enum BibleCatalogError: LocalizedError, Sendable {
    case missingResource(name: String, fileExtension: String)
    case readFailed(underlyingDescription: String)
    case decodeFailed(underlyingDescription: String)

    public var errorDescription: String? {
        switch self {
        case let .missingResource(name, fileExtension):
            return "Missing bundled resource: \(name).\(fileExtension)"
        case let .readFailed(underlyingDescription):
            return "Failed reading Bible catalog resource. \(underlyingDescription)"
        case let .decodeFailed(underlyingDescription):
            return "Failed decoding Bible catalog resource. \(underlyingDescription)"
        }
    }
}

public enum BibleCatalog {
    private static let logger = Logger(subsystem: "com.griffinbarnard.ScriptureMemory", category: "BibleCatalog")

    public static var initializationError: BibleCatalogError? {
        if case let .failed(error) = state {
            return error
        }
        return nil
    }

    public static var books: [BibleBookSummary] {
        store.books.map { book in
            BibleBookSummary(
                id: book.id,
                number: book.number,
                name: book.name,
                chapterCount: book.chapters.count
            )
        }
    }

    public static func bookName(for bookID: String) -> String? {
        store.booksByID[bookID]?.name
    }

    public static func bookID(for bookName: String) -> String? {
        store.bookIDByName[bookName]
    }

    public static func bookNumber(for bookName: String) -> Int? {
        guard let bookID = bookID(for: bookName) else { return nil }
        return store.booksByID[bookID]?.number
    }

    public static func chapterNumbers(in bookID: String) -> [Int] {
        store.booksByID[bookID]?.chapters.map(\.number) ?? []
    }

    public static func lastVerseNumber(in bookID: String, chapter: Int) -> Int {
        store.booksByID[bookID]?
            .chapters
            .first(where: { $0.number == chapter })?
            .verses
            .last?
            .number ?? 1
    }

    public static func verse(bookID: String, chapter: Int, verse: Int, setID: UUID, order: Int = 1) -> ScriptureVerse? {
        guard
            let book = store.booksByID[bookID],
            let chapterRecord = book.chapters.first(where: { $0.number == chapter }),
            let verseRecord = chapterRecord.verses.first(where: { $0.number == verse })
        else {
            return nil
        }

        return makeVerse(
            book: book,
            chapter: chapterRecord.number,
            verse: verseRecord,
            setID: setID,
            order: order
        )
    }

    public static func verse(withID id: UUID, setID: UUID = BuiltInContent.myVersesSetID) -> ScriptureVerse? {
        guard let index = store.referenceByVerseID[id] else { return nil }
        return verse(
            bookID: index.bookID,
            chapter: index.chapter,
            verse: index.verse,
            setID: setID,
            order: index.order
        )
    }

    public static func verseRange(
        bookID: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int,
        setID: UUID
    ) -> [ScriptureVerse] {
        guard
            let book = store.booksByID[bookID],
            startChapter <= endChapter,
            startChapter > 0,
            startVerse > 0,
            endVerse > 0
        else {
            return []
        }

        if startChapter == endChapter, startVerse > endVerse {
            return []
        }

        let start = VerseCursor(chapter: startChapter, verse: startVerse)
        let end = VerseCursor(chapter: endChapter, verse: endVerse)
        var order = 1
        var verses: [ScriptureVerse] = []

        for chapterRecord in book.chapters where chapterRecord.number >= startChapter && chapterRecord.number <= endChapter {
            for verseRecord in chapterRecord.verses {
                let cursor = VerseCursor(chapter: chapterRecord.number, verse: verseRecord.number)
                guard cursor >= start, cursor <= end else { continue }

                verses.append(
                    makeVerse(
                        book: book,
                        chapter: chapterRecord.number,
                        verse: verseRecord,
                        setID: setID,
                        order: order
                    )
                )
                order += 1
            }
        }

        return verses
    }

    public static func surroundingVerses(
        bookID: String,
        chapter: Int,
        verseNumber: Int,
        range: Int = 1,
        setID: UUID = BuiltInContent.myVersesSetID
    ) -> (before: [ScriptureVerse], after: [ScriptureVerse]) {
        let lastVerse = lastVerseNumber(in: bookID, chapter: chapter)
        var before: [ScriptureVerse] = []
        var after: [ScriptureVerse] = []

        for offset in (1...range).reversed() {
            let v = verseNumber - offset
            if v >= 1, let sv = verse(bookID: bookID, chapter: chapter, verse: v, setID: setID) {
                before.append(sv)
            }
        }

        for offset in 1...range {
            let v = verseNumber + offset
            if v <= lastVerse, let sv = verse(bookID: bookID, chapter: chapter, verse: v, setID: setID) {
                after.append(sv)
            }
        }

        return (before, after)
    }

    private enum LoadState {
        case loaded(BibleStore)
        case failed(BibleCatalogError)
    }

    private static let state = makeState()

    private static var store: BibleStore {
        switch state {
        case let .loaded(store):
            return store
        case .failed:
            return BibleStore(books: [])
        }
    }

    private static func makeState() -> LoadState {
        do {
            return .loaded(try BibleStore.load())
        } catch let error as BibleCatalogError {
            logger.error("Bible catalog initialization failed: \(error.localizedDescription, privacy: .public)")
            return .failed(error)
        } catch {
            let typedError = BibleCatalogError.decodeFailed(underlyingDescription: String(describing: error))
            logger.error("Bible catalog initialization failed with unexpected error: \(typedError.localizedDescription, privacy: .public)")
            return .failed(typedError)
        }
    }

    private static func makeVerse(
        book: BibleBook,
        chapter: Int,
        verse: BibleVerse,
        setID: UUID,
        order: Int
    ) -> ScriptureVerse {
        let verseID = BuiltInContent.fixedVerseID(book: book.name, chapter: chapter, verse: verse.number)
            ?? derivedVerseID(bookID: book.id, chapter: chapter, verse: verse.number)

        return ScriptureVerse(
            id: verseID,
            setID: setID,
            order: order,
            bookID: book.id,
            bookNumber: book.number,
            book: book.name,
            chapter: chapter,
            verse: verse.number,
            kjvText: verse.kjv,
            webText: verse.web
        )
    }

    fileprivate static func derivedVerseID(bookID: String, chapter: Int, verse: Int) -> UUID {
        let seed = "scripture-memory:\(bookID):\(chapter):\(verse)"
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

    static func _loadStoreForTesting(
        resourceURLProvider: () -> URL?,
        fileLoader: (URL) throws -> Data
    ) throws -> BibleStore {
        try BibleStore.load(resourceURLProvider: resourceURLProvider, fileLoader: fileLoader)
    }
}

private struct VerseCursor: Comparable {
    let chapter: Int
    let verse: Int

    static func < (lhs: VerseCursor, rhs: VerseCursor) -> Bool {
        if lhs.chapter == rhs.chapter {
            return lhs.verse < rhs.verse
        }
        return lhs.chapter < rhs.chapter
    }
}

struct BibleStore: Decodable {
    let books: [BibleBook]

    let booksByID: [String: BibleBook]
    let bookIDByName: [String: String]
    let referenceByVerseID: [UUID: VerseLookup]

    init(books: [BibleBook]) {
        self.books = books
        self.booksByID = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        self.bookIDByName = Dictionary(uniqueKeysWithValues: books.map { ($0.name, $0.id) })

        var verseLookup: [UUID: VerseLookup] = [:]
        for book in books {
            var order = 1
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let verseID = BuiltInContent.fixedVerseID(book: book.name, chapter: chapter.number, verse: verse.number)
                        ?? BibleCatalog.derivedVerseID(bookID: book.id, chapter: chapter.number, verse: verse.number)
                    verseLookup[verseID] = VerseLookup(
                        bookID: book.id,
                        chapter: chapter.number,
                        verse: verse.number,
                        order: order
                    )
                    order += 1
                }
            }
        }
        self.referenceByVerseID = verseLookup
    }

    private enum CodingKeys: String, CodingKey {
        case books
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let books = try container.decode([BibleBook].self, forKey: .books)
        self.init(books: books)
    }

    static func load(
        resourceURLProvider: () -> URL? = { Bundle.module.url(forResource: "bible-data", withExtension: "json") },
        fileLoader: (URL) throws -> Data = { try Data(contentsOf: $0) }
    ) throws -> BibleStore {
        guard let url = resourceURLProvider() else {
            throw BibleCatalogError.missingResource(name: "bible-data", fileExtension: "json")
        }

        do {
            let data = try fileLoader(url)
            do {
                return try JSONDecoder().decode(BibleStore.self, from: data)
            } catch {
                throw BibleCatalogError.decodeFailed(underlyingDescription: String(describing: error))
            }
        } catch let error as BibleCatalogError {
            throw error
        } catch {
            throw BibleCatalogError.readFailed(underlyingDescription: String(describing: error))
        }
    }
}

private struct VerseLookup: Hashable {
    let bookID: String
    let chapter: Int
    let verse: Int
    let order: Int
}

struct BibleBook: Codable, Sendable {
    let number: Int
    let id: String
    let name: String
    let chapters: [BibleChapter]
}

struct BibleChapter: Codable, Sendable {
    let number: Int
    let verses: [BibleVerse]
}

struct BibleVerse: Codable, Sendable {
    let number: Int
    let kjv: String
    let web: String
}
