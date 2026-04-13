import SwiftUI
import Observation

struct PeopleView: View {
    @State private var socialService = SocialService.shared
    @State private var viewModel = PeopleViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sortingControls

                if socialService.isLoading, viewModel.people.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if viewModel.people.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.sortedPeople) { person in
                        personCard(for: person)
                    }
                }

                if let error = socialService.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .cardSurface()
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .task {
            await socialService.fetchGroups()
            viewModel.groups = socialService.groups
        }
        .refreshable {
            await socialService.fetchGroups()
            viewModel.groups = socialService.groups
        }
        .onChange(of: socialService.groups) { _, newValue in
            viewModel.groups = newValue
        }
    }

    private var sortingControls: some View {
        Picker("Sort", selection: $viewModel.sortOption) {
            ForEach(PeopleSortOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentMoss)

            Text("No people yet")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text("People appear when you share a plan.")
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)
        }
        .cardSurface()
    }

    private func personCard(for person: PersonSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    Text("\(person.plansInCommonCount) \(person.plansInCommonCount == 1 ? "plan" : "plans") in common")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }
                Spacer()
                Label("\(person.highestStreak)", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentGold)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most progress")
                        .font(.caption2)
                        .foregroundStyle(Color.mutedText)
                    Text("Day \(person.mostAdvancedDay)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last active")
                        .font(.caption2)
                        .foregroundStyle(Color.mutedText)
                    Text(relativeDate(person.lastActiveAt))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                }
            }
        }
        .cardSurface()
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date else { return "No activity yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

@MainActor
@Observable
final class PeopleViewModel {
    var groups: [SharedPlanGroup] = []
    var sortOption: PeopleSortOption = .mostActive

    var people: [PersonSummary] {
        var membersByID: [String: [MemberContext]] = [:]

        for group in groups {
            for member in group.members {
                membersByID[member.id, default: []].append(MemberContext(member: member, groupID: group.id))
            }
        }

        return membersByID.map { memberID, contexts in
            let sortedContexts = contexts.sorted { left, right in
                (left.member.lastActiveAt ?? .distantPast) > (right.member.lastActiveAt ?? .distantPast)
            }
            let preferred = sortedContexts.first?.member ?? contexts[0].member
            return PersonSummary(
                id: memberID,
                displayName: preferred.displayName,
                highestStreak: contexts.map(\.member.streak).max() ?? 0,
                lastActiveAt: contexts.compactMap(\.member.lastActiveAt).max(),
                plansInCommonCount: Set(contexts.map(\.groupID)).count,
                mostAdvancedDay: contexts.map(\.member.currentDay).max() ?? 1
            )
        }
    }

    var sortedPeople: [PersonSummary] {
        people.sorted { lhs, rhs in
            switch sortOption {
            case .mostActive:
                if lhs.plansInCommonCount == rhs.plansInCommonCount {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.plansInCommonCount > rhs.plansInCommonCount
            case .highestStreak:
                if lhs.highestStreak == rhs.highestStreak {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.highestStreak > rhs.highestStreak
            case .recentlyActive:
                return (lhs.lastActiveAt ?? .distantPast) > (rhs.lastActiveAt ?? .distantPast)
            }
        }
    }
}

struct PersonSummary: Identifiable, Hashable {
    let id: String
    let displayName: String
    let highestStreak: Int
    let lastActiveAt: Date?
    let plansInCommonCount: Int
    let mostAdvancedDay: Int
}

private struct MemberContext: Hashable {
    let member: PlanMembership
    let groupID: String
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

#Preview {
    NavigationStack {
        PeopleView()
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environment(AppModel(progressStore: ReviewProgressStore.initialize(inMemory: true).store))
}
