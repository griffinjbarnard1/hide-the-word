import Foundation
import Testing
@testable import ScriptureMemory

struct ReferenceSearchTests {
    private let books = [
        BibleBookSummary(id: "genesis", number: 1, name: "Genesis", chapterCount: 50),
        BibleBookSummary(id: "joshua", number: 6, name: "Joshua", chapterCount: 24),
        BibleBookSummary(id: "judges", number: 7, name: "Judges", chapterCount: 21),
        BibleBookSummary(id: "psalms", number: 19, name: "Psalms", chapterCount: 150),
        BibleBookSummary(id: "songofsolomon", number: 22, name: "Song of Solomon", chapterCount: 8),
        BibleBookSummary(id: "john", number: 43, name: "John", chapterCount: 21),
        BibleBookSummary(id: "philippians", number: 50, name: "Philippians", chapterCount: 4),
        BibleBookSummary(id: "philemon", number: 57, name: "Philemon", chapterCount: 1),
        BibleBookSummary(id: "1john", number: 62, name: "1 John", chapterCount: 5),
    ]

    @Test
    func matchesFullReference() {
        let match = ReferenceSearch.match("John 3:16", books: books)
        #expect(match?.bookID == "john")
        #expect(match?.chapter == 3)
        #expect(match?.startVerse == 16)
        #expect(match?.endVerse == nil)
        #expect(match?.displayReference == "John 3:16")
    }

    @Test
    func matchesVerseRange() {
        let match = ReferenceSearch.match("john 3:16-18", books: books)
        #expect(match?.startVerse == 16)
        #expect(match?.endVerse == 18)
        #expect(match?.displayReference == "John 3:16-18")
    }

    @Test
    func matchesNumberedBook() {
        let match = ReferenceSearch.match("1 john 1:9", books: books)
        #expect(match?.bookID == "1john")
        #expect(match?.chapter == 1)
        #expect(match?.startVerse == 9)
    }

    @Test
    func matchesCommonAbbreviations() {
        #expect(ReferenceSearch.match("jn 3:16", books: books)?.bookID == "john")
        #expect(ReferenceSearch.match("ps 23", books: books)?.bookID == "psalms")
        #expect(ReferenceSearch.match("psalm 23:1", books: books)?.bookID == "psalms")
        #expect(ReferenceSearch.match("phil 4:13", books: books)?.bookID == "philippians")
        #expect(ReferenceSearch.match("1 jn 1:9", books: books)?.bookID == "1john")
    }

    @Test
    func matchesBookNamePrefix() {
        #expect(ReferenceSearch.match("philip 4:13", books: books)?.bookID == "philippians")
        #expect(ReferenceSearch.match("song 2:1", books: books)?.bookID == "songofsolomon")
        #expect(ReferenceSearch.match("gen 1:1", books: books)?.bookID == "genesis")
    }

    @Test
    func bareChapterLeavesVersesOpen() {
        let match = ReferenceSearch.match("psalm 23", books: books)
        #expect(match?.chapter == 23)
        #expect(match?.startVerse == nil)
        #expect(match?.displayReference == "Psalms 23")
    }

    @Test
    func bareBookDefaultsToChapterOne() {
        let match = ReferenceSearch.match("john", books: books)
        #expect(match?.bookID == "john")
        #expect(match?.chapter == 1)
        #expect(match?.startVerse == nil)
    }

    @Test
    func toleratesMissingSpacesAndPunctuation() {
        #expect(ReferenceSearch.match("jn3:16", books: books)?.startVerse == 16)
        #expect(ReferenceSearch.match("ps. 23", books: books)?.chapter == 23)
        #expect(ReferenceSearch.match("john 3.16", books: books)?.startVerse == 16)
        #expect(ReferenceSearch.match("john 3 16", books: books)?.startVerse == 16)
    }

    @Test
    func clampsChapterToBook() {
        #expect(ReferenceSearch.match("john 99", books: books)?.chapter == 21)
        #expect(ReferenceSearch.match("john 0:5", books: books)?.chapter == 1)
    }

    @Test
    func normalizesInvertedAndEqualRanges() {
        let inverted = ReferenceSearch.match("john 3:18-16", books: books)
        #expect(inverted?.startVerse == 16)
        #expect(inverted?.endVerse == 18)

        let equal = ReferenceSearch.match("john 3:16-16", books: books)
        #expect(equal?.startVerse == 16)
        #expect(equal?.endVerse == nil)
    }

    @Test
    func rejectsUnknownAndTooShortQueries() {
        #expect(ReferenceSearch.match("xyzzy 3:16", books: books) == nil)
        #expect(ReferenceSearch.match("j 3:16", books: books) == nil)
        #expect(ReferenceSearch.match("", books: books) == nil)
        #expect(ReferenceSearch.match("   ", books: books) == nil)
        #expect(ReferenceSearch.match("3:16", books: books) == nil)
    }
}
