import Foundation

/// One person aggregated across every shared plan they appear in.
///
/// People are derived from plan memberships only — there is no global friend
/// graph yet. The same person can hold different progress in different plans,
/// so a summary merges their best streak/progress and most recent activity.
struct PersonSummary: Identifiable, Hashable {
    let id: String
    let displayName: String
    let highestStreak: Int
    let lastActiveAt: Date?
    let plansInCommonCount: Int
    let mostAdvancedDay: Int
}

/// A person summary paired with their most recently active membership,
/// which carries the profile (bio, favorite verse, avatar seed) for display.
struct PersonSummaryEntry: Identifiable {
    var id: String { summary.id }
    let summary: PersonSummary
    let representativeMember: PlanMembership
}

enum PeopleSortOption: String, CaseIterable, Identifiable {
    case mostActive
    case highestStreak
    case recentlyActive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostActive:
            return "Most active"
        case .highestStreak:
            return "Highest streak"
        case .recentlyActive:
            return "Recently active"
        }
    }
}

enum PeopleSummaryBuilder {
    static func entries(from groups: [SharedPlanGroup], sortedBy option: PeopleSortOption) -> [PersonSummaryEntry] {
        var contextsByMemberID: [String: [MemberContext]] = [:]

        for group in groups {
            for member in group.members {
                contextsByMemberID[member.id, default: []].append(MemberContext(member: member, groupID: group.id))
            }
        }

        let entries = contextsByMemberID.compactMap { memberID, contexts -> PersonSummaryEntry? in
            guard let representative = contexts.max(by: {
                ($0.member.lastActiveAt ?? .distantPast) < ($1.member.lastActiveAt ?? .distantPast)
            })?.member else {
                return nil
            }

            let summary = PersonSummary(
                id: memberID,
                displayName: representative.profile?.displayName ?? representative.displayName,
                highestStreak: contexts.map(\.member.streak).max() ?? 0,
                lastActiveAt: contexts.compactMap(\.member.lastActiveAt).max(),
                plansInCommonCount: Set(contexts.map(\.groupID)).count,
                mostAdvancedDay: contexts.map(\.member.currentDay).max() ?? 1
            )
            return PersonSummaryEntry(summary: summary, representativeMember: representative)
        }

        return entries.sorted { lhs, rhs in
            switch option {
            case .mostActive:
                if lhs.summary.plansInCommonCount == rhs.summary.plansInCommonCount {
                    return lhs.summary.displayName.localizedCaseInsensitiveCompare(rhs.summary.displayName) == .orderedAscending
                }
                return lhs.summary.plansInCommonCount > rhs.summary.plansInCommonCount
            case .highestStreak:
                if lhs.summary.highestStreak == rhs.summary.highestStreak {
                    return lhs.summary.displayName.localizedCaseInsensitiveCompare(rhs.summary.displayName) == .orderedAscending
                }
                return lhs.summary.highestStreak > rhs.summary.highestStreak
            case .recentlyActive:
                return (lhs.summary.lastActiveAt ?? .distantPast) > (rhs.summary.lastActiveAt ?? .distantPast)
            }
        }
    }
}

private struct MemberContext {
    let member: PlanMembership
    let groupID: String
}
