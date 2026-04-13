import Foundation

public struct SessionConfig: Hashable, Codable, Sendable {
    public var maxReviewItems: Int
    public var maxTotalItems: Int
    public var allowsNewVerseWhenReviewsRemain: Bool

    public init(
        maxReviewItems: Int = 5,
        maxTotalItems: Int = 6,
        allowsNewVerseWhenReviewsRemain: Bool = true
    ) {
        self.maxReviewItems = maxReviewItems
        self.maxTotalItems = maxTotalItems
        self.allowsNewVerseWhenReviewsRemain = allowsNewVerseWhenReviewsRemain
    }
}

public enum ReviewScheduler {
    public static func buildPlan(
        units: [StudyUnit],
        progressByUnitID: [UUID: VerseProgress],
        on date: Date,
        config: SessionConfig = .init()
    ) -> DailySessionPlan {
        let orderedUnits = units.sorted { lhs, rhs in
            lhs.order < rhs.order
        }

        let dueReviewUnits = orderedUnits
            .filter { unit in
                guard let progress = progressByUnitID[unit.id] else { return false }
                return progress.isDue(on: date)
            }
            .sorted { lhs, rhs in
                let lhsDate = progressByUnitID[lhs.id]?.nextReviewAt ?? .distantFuture
                let rhsDate = progressByUnitID[rhs.id]?.nextReviewAt ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.order < rhs.order
                }
                return lhsDate < rhsDate
            }

        let reviewItems = dueReviewUnits
            .prefix(config.maxReviewItems)
            .map { SessionItem(unit: $0, kind: .review) }

        let hasCapacityForNewVerse = reviewItems.count < config.maxTotalItems
        let canAddNewVerse = config.allowsNewVerseWhenReviewsRemain || reviewItems.isEmpty

        let nextUnseenUnit = orderedUnits.first { unit in
            !(progressByUnitID[unit.id]?.isStarted ?? false)
        }

        let newVerseItem: SessionItem?
        if hasCapacityForNewVerse, canAddNewVerse, let nextUnseenUnit {
            newVerseItem = SessionItem(unit: nextUnseenUnit, kind: .newVerse)
        } else {
            newVerseItem = nil
        }

        var items = reviewItems
        if let newVerseItem {
            items.append(newVerseItem)
        }

        if items.isEmpty,
           let fallbackUnit = orderedUnits
            .filter({ progressByUnitID[$0.id]?.isStarted ?? false })
            .sorted(by: { lhs, rhs in
                let lhsNext = progressByUnitID[lhs.id]?.nextReviewAt ?? .distantFuture
                let rhsNext = progressByUnitID[rhs.id]?.nextReviewAt ?? .distantFuture
                if lhsNext == rhsNext {
                    let lhsLast = progressByUnitID[lhs.id]?.lastReviewedAt ?? .distantPast
                    let rhsLast = progressByUnitID[rhs.id]?.lastReviewedAt ?? .distantPast
                    if lhsLast == rhsLast {
                        return lhs.order < rhs.order
                    }
                    return lhsLast < rhsLast
                }
                return lhsNext < rhsNext
            })
            .first {
            items = [SessionItem(unit: fallbackUnit, kind: .review)]
        }

        return DailySessionPlan(
            generatedAt: date,
            items: items,
            dueReviewCount: dueReviewUnits.count
        )
    }

    public static func apply(
        rating: ReviewRating,
        to unit: StudyUnit,
        existing progress: VerseProgress?,
        reviewedAt date: Date,
        calendar: Calendar = .current
    ) -> VerseProgress {
        let existingProgress = progress ?? VerseProgress(verseID: unit.id)
        let nextInterval = recommendedIntervalDays(
            after: rating,
            currentInterval: existingProgress.intervalDays,
            reviewCount: existingProgress.reviewCount
        )

        return VerseProgress(
            verseID: unit.id,
            reviewCount: existingProgress.reviewCount + 1,
            intervalDays: nextInterval,
            lastReviewedAt: date,
            nextReviewAt: calendar.date(byAdding: .day, value: nextInterval, to: date),
            lastRating: rating
        )
    }

    static func recommendedIntervalDays(
        after rating: ReviewRating,
        currentInterval: Int,
        reviewCount: Int
    ) -> Int {
        if reviewCount == 0 {
            switch rating {
            case .hard:
                return 1
            case .medium:
                return 2
            case .easy:
                return 4
            }
        }

        let safeCurrentInterval = max(currentInterval, 1)

        switch rating {
        case .hard:
            return max(1, safeCurrentInterval / 2)
        case .medium:
            return max(2, Int((Double(safeCurrentInterval) * 1.5).rounded()))
        case .easy:
            return min(180, max(3, Int((Double(safeCurrentInterval) * 2.2).rounded())))
        }
    }
}
