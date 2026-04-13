import Foundation

public enum AppAppearance: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

public enum BibleTranslation: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case esv
    case kjv
    case web

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .esv:
            return "ESV"
        case .kjv:
            return "KJV"
        case .web:
            return "WEB"
        }
    }

    public var displayName: String {
        switch self {
        case .esv:
            return "English Standard Version"
        case .kjv:
            return "King James Version"
        case .web:
            return "World English Bible"
        }
    }
}

public enum SessionSizePreset: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case light
    case standard
    case focused

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .light:
            return "Light"
        case .standard:
            return "Standard"
        case .focused:
            return "Focused"
        }
    }

    public var subtitle: String {
        switch self {
        case .light:
            return "Short daily touchpoint"
        case .standard:
            return "Balanced daily session"
        case .focused:
            return "Deeper review block"
        }
    }

    public var sessionConfig: SessionConfig {
        switch self {
        case .light:
            return SessionConfig(maxReviewItems: 3, maxTotalItems: 4, allowsNewVerseWhenReviewsRemain: true)
        case .standard:
            return SessionConfig(maxReviewItems: 5, maxTotalItems: 6, allowsNewVerseWhenReviewsRemain: true)
        case .focused:
            return SessionConfig(maxReviewItems: 8, maxTotalItems: 9, allowsNewVerseWhenReviewsRemain: true)
        }
    }
}

public struct VerseSet: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let summary: String
    public let systemImageName: String
    public let isCustom: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        systemImageName: String,
        isCustom: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.systemImageName = systemImageName
        self.isCustom = isCustom
    }
}

public struct ScriptureVerse: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let setID: UUID
    public let order: Int
    public let bookID: String
    public let bookNumber: Int
    public let book: String
    public let chapter: Int
    public let verse: Int
    public let kjvText: String
    public let webText: String

    public init(
        id: UUID = UUID(),
        setID: UUID,
        order: Int,
        bookID: String = "",
        bookNumber: Int = 0,
        book: String,
        chapter: Int,
        verse: Int,
        kjvText: String,
        webText: String
    ) {
        self.id = id
        self.setID = setID
        self.order = order
        self.bookID = bookID
        self.bookNumber = bookNumber
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.kjvText = kjvText
        self.webText = webText
    }

    public var reference: String {
        "\(book) \(chapter):\(verse)"
    }

    public func text(in translation: BibleTranslation) -> String {
        switch translation {
        case .esv:
            return kjvText
        case .kjv:
            return kjvText
        case .web:
            return webText
        }
    }
}

public enum StudyUnitKind: String, Codable, Hashable, Sendable {
    case singleVerse
    case passage
}

public enum StudyUnitTrack: String, Codable, Hashable, Sendable, CaseIterable {
    case scheduled
    case practiceOnly

    public var title: String {
        switch self {
        case .scheduled:
            return "Scheduled"
        case .practiceOnly:
            return "Practice only"
        }
    }
}

public struct StudyUnit: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let collectionID: UUID
    public let order: Int
    public let kind: StudyUnitKind
    public let track: StudyUnitTrack
    public let title: String
    public let reference: String
    public let kjvText: String
    public let webText: String
    public let verseIDs: [UUID]

    public init(
        id: UUID,
        collectionID: UUID,
        order: Int,
        kind: StudyUnitKind,
        track: StudyUnitTrack = .scheduled,
        title: String,
        reference: String,
        kjvText: String,
        webText: String,
        verseIDs: [UUID]
    ) {
        self.id = id
        self.collectionID = collectionID
        self.order = order
        self.kind = kind
        self.track = track
        self.title = title
        self.reference = reference
        self.kjvText = kjvText
        self.webText = webText
        self.verseIDs = verseIDs
    }

    public func text(in translation: BibleTranslation) -> String {
        switch translation {
        case .esv:
            return kjvText
        case .kjv:
            return kjvText
        case .web:
            return webText
        }
    }
}

public enum ReviewRating: String, Codable, CaseIterable, Hashable, Sendable {
    case hard
    case medium
    case easy
}

public struct VerseProgress: Hashable, Codable, Sendable {
    public let verseID: UUID
    public var reviewCount: Int
    public var intervalDays: Int
    public var lastReviewedAt: Date?
    public var nextReviewAt: Date?
    public var lastRating: ReviewRating?

    public init(
        verseID: UUID,
        reviewCount: Int = 0,
        intervalDays: Int = 0,
        lastReviewedAt: Date? = nil,
        nextReviewAt: Date? = nil,
        lastRating: ReviewRating? = nil
    ) {
        self.verseID = verseID
        self.reviewCount = reviewCount
        self.intervalDays = intervalDays
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.lastRating = lastRating
    }

    public var isStarted: Bool {
        reviewCount > 0 || lastReviewedAt != nil || nextReviewAt != nil
    }

    public func isDue(on date: Date) -> Bool {
        guard let nextReviewAt else { return false }
        return nextReviewAt <= date
    }

    public var masteryTier: MasteryTier {
        MasteryTier.from(reviewCount: reviewCount, intervalDays: intervalDays)
    }
}

public enum MasteryTier: String, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case learning
    case familiar
    case memorized
    case mastered

    public static func from(reviewCount: Int, intervalDays: Int) -> MasteryTier {
        if reviewCount >= 8, intervalDays >= 60 { return .mastered }
        if reviewCount >= 5, intervalDays >= 15 { return .memorized }
        if reviewCount >= 3, intervalDays >= 4 { return .familiar }
        return .learning
    }

    public var title: String {
        switch self {
        case .learning: return "Learning"
        case .familiar: return "Familiar"
        case .memorized: return "Memorized"
        case .mastered: return "Mastered"
        }
    }

    public var systemImage: String {
        switch self {
        case .learning: return "leaf"
        case .familiar: return "leaf.fill"
        case .memorized: return "checkmark.seal"
        case .mastered: return "checkmark.seal.fill"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .learning: return 0
        case .familiar: return 1
        case .memorized: return 2
        case .mastered: return 3
        }
    }

    public static func < (lhs: MasteryTier, rhs: MasteryTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

public enum SessionItemKind: String, Hashable, Codable, Sendable {
    case review
    case newVerse
    case restudy
}

public struct SessionItem: Hashable, Codable, Sendable {
    public let unit: StudyUnit
    public let kind: SessionItemKind

    public init(unit: StudyUnit, kind: SessionItemKind) {
        self.unit = unit
        self.kind = kind
    }
}

public struct DailySessionPlan: Hashable, Codable, Sendable {
    public let generatedAt: Date
    public let items: [SessionItem]
    public let dueReviewCount: Int

    public init(generatedAt: Date, items: [SessionItem], dueReviewCount: Int) {
        self.generatedAt = generatedAt
        self.items = items
        self.dueReviewCount = dueReviewCount
    }

    public var includesNewVerse: Bool {
        items.contains(where: { $0.kind == .newVerse })
    }
}

// MARK: - Memorization Plans

public enum PlanCategory: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case book
    case thematic
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .book: return "Book Studies"
        case .thematic: return "Topical"
        case .custom: return "Custom"
        }
    }
}

public enum PlanDayGoal: String, Codable, Hashable, Sendable {
    case learnNew
    case reviewOnly
    case fullRecall
    case rest
}

public struct VerseReference: Codable, Hashable, Sendable {
    public let bookID: String
    public let chapter: Int
    public let verse: Int

    public init(bookID: String, chapter: Int, verse: Int) {
        self.bookID = bookID
        self.chapter = chapter
        self.verse = verse
    }

    public var displayReference: String {
        "\(bookID) \(chapter):\(verse)"
    }
}

public struct PlanDay: Codable, Hashable, Sendable, Identifiable {
    public let dayNumber: Int
    public let title: String
    public let verseReferences: [VerseReference]
    public let goal: PlanDayGoal

    public var id: Int { dayNumber }

    public init(dayNumber: Int, title: String, verseReferences: [VerseReference], goal: PlanDayGoal) {
        self.dayNumber = dayNumber
        self.title = title
        self.verseReferences = verseReferences
        self.goal = goal
    }
}

public struct MemorizationPlan: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let systemImageName: String
    public let category: PlanCategory
    public let days: [PlanDay]
    public let isBuiltIn: Bool

    public var duration: Int { days.count }

    public var learnDayCount: Int {
        days.filter { $0.goal == .learnNew }.count
    }

    public var totalVerseCount: Int {
        Set(days.flatMap(\.verseReferences)).count
    }

    public init(id: UUID, title: String, description: String, systemImageName: String, category: PlanCategory, days: [PlanDay], isBuiltIn: Bool) {
        self.id = id
        self.title = title
        self.description = description
        self.systemImageName = systemImageName
        self.category = category
        self.days = days
        self.isBuiltIn = isBuiltIn
    }
}

public enum PlanDayGenerator {
    /// Auto-generates plan days from a list of verse references.
    /// Groups ~2 verses per learn day, inserts review days every 3rd learn day,
    /// and appends a full recall day at the end.
    public static func generateDays(from references: [VerseReference]) -> [PlanDay] {
        guard !references.isEmpty else { return [] }

        let versesPerDay = 2
        let chunks = stride(from: 0, to: references.count, by: versesPerDay).map {
            Array(references[$0..<min($0 + versesPerDay, references.count)])
        }

        var days: [PlanDay] = []
        var dayNumber = 1
        var learnDaysSinceReview = 0

        for chunk in chunks {
            let title: String
            if chunk.count == 1 {
                title = chunk[0].displayReference
            } else if let first = chunk.first, let last = chunk.last {
                title = "\(first.displayReference)-\(last.verse)"
            } else {
                continue
            }

            days.append(PlanDay(
                dayNumber: dayNumber,
                title: title,
                verseReferences: chunk,
                goal: .learnNew
            ))
            dayNumber += 1
            learnDaysSinceReview += 1

            if learnDaysSinceReview >= 3 && dayNumber <= chunks.count {
                days.append(PlanDay(
                    dayNumber: dayNumber,
                    title: "Review day",
                    verseReferences: [],
                    goal: .reviewOnly
                ))
                dayNumber += 1
                learnDaysSinceReview = 0
            }
        }

        if references.count > 2 {
            days.append(PlanDay(
                dayNumber: dayNumber,
                title: "Full recall",
                verseReferences: references,
                goal: .fullRecall
            ))
        }

        return days
    }
}

public struct PlanEnrollment: Codable, Hashable, Sendable, Identifiable {
    public let planID: UUID
    public let startedAt: Date
    public var currentDay: Int
    public var completedDays: Set<Int>
    public var lastActiveAt: Date?

    public var id: UUID { planID }

    public var isComplete: Bool {
        guard let maxDay = completedDays.max() else { return false }
        return maxDay >= currentDay
    }

    public init(planID: UUID, startedAt: Date, currentDay: Int = 1, completedDays: Set<Int> = [], lastActiveAt: Date? = nil) {
        self.planID = planID
        self.startedAt = startedAt
        self.currentDay = currentDay
        self.completedDays = completedDays
        self.lastActiveAt = lastActiveAt
    }
}
