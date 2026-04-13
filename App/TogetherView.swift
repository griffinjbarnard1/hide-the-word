import SwiftUI
import ScriptureMemory
import CloudKit

struct TogetherView: View {
    private enum SectionTab: String, CaseIterable, Identifiable {
        case plans = "Plans"
        case people = "People"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var appModel
    @State private var socialService = SocialService.shared
    @State private var selectedGroup: SharedPlanGroup?
    @State private var sharingGroup: SharedPlanGroup?
    @State private var selectedTab: SectionTab = .plans
    @State private var selectedPerson: PlanMembership?
    @State private var peopleSortOption: PeopleSortOption = .mostActive
    @State private var showingProfileEditor = false
    @State private var currentMemberID: String?
    @State private var pendingLeaveGroup: SharedPlanGroup?
    @State private var actionMessage: String?
    @State private var identityStatus: SharedPlanManager.IdentityStatus = .unavailable
    @State private var cloudActionError: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Picker("Together section", selection: $selectedTab) {
                    ForEach(SectionTab.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                if selectedTab == .plans, socialService.isLoading, socialService.groups.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if selectedTab == .plans, socialService.groups.isEmpty {
                    emptyState
                } else if selectedTab == .plans {
                    ForEach(socialService.groups) { group in
                        groupCard(group)
                    }
                } else {
                    peopleTab
                }

                if let error = presentableError {
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
            await refreshIdentity()
            await socialService.fetchGroups()
            currentMemberID = await socialService.stableMemberID()
        }
        .refreshable {
            await refreshIdentity()
            await socialService.fetchGroups()
        }
        .sheet(item: $selectedGroup) { group in
            NavigationStack {
                SharedPlanDetailView(group: group, socialService: socialService)
            }
        }
        .sheet(item: $sharingGroup) { group in
            PlanCloudSharingSheet(group: group)
        }
        .sheet(item: $selectedPerson) { person in
            NavigationStack {
                PersonDetailView(member: person)
            }
        }
        .sheet(isPresented: $showingProfileEditor) {
            NavigationStack {
                PublicProfileEditorView()
                    .environment(appModel)
            }
        }
        .confirmationDialog("Leave shared plan?", isPresented: Binding(
            get: { pendingLeaveGroup != nil },
            set: { if !$0 { pendingLeaveGroup = nil } }
        ), titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                guard let group = pendingLeaveGroup else { return }
                Task {
                    let feedback = await socialService.leaveGroup(group, currentDisplayName: appModel.userDisplayName)
                    actionMessage = feedback.message
                    pendingLeaveGroup = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingLeaveGroup = nil
            }
        } message: {
            Text("You'll stop seeing this plan and your progress updates will no longer sync to the group.")
        }
        .alert("Shared Plan", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Together")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primaryText)
                Spacer()
                if appModel.activePlan != nil {
                    Button {
                        Task { await shareActivePlan() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentMoss)
                    }
                }
            }

            Text("Memorize together. Invite others to a plan and track each other's progress.")
                .font(.body)
                .foregroundStyle(Color.mutedText)
        }
    }

    // MARK: - Empty State

    private var peopleTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button("Edit my profile") {
                showingProfileEditor = true
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("People appear from shared plans you are part of. There is no global friend list yet.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)
                .cardSurface()

            if peopleSummaries.isEmpty {
                Text("No people yet — share a plan to start memorizing together.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mutedText)
                    .cardSurface()
            } else {
                Picker("Sort people", selection: $peopleSortOption) {
                    ForEach(PeopleSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                peopleStatsRow

                ForEach(peopleSummaries) { person in
                    Button {
                        selectedPerson = person.representativeMember
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                ProfileAvatarView(member: person.representativeMember, size: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(person.summary.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                    Text("\(person.summary.plansInCommonCount) \(person.summary.plansInCommonCount == 1 ? "plan" : "plans") in common")
                                        .font(.caption)
                                        .foregroundStyle(Color.mutedText)
                                }
                                Spacer()
                                Label("\(person.summary.highestStreak)", systemImage: "flame.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentGold)
                            }

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Most progress")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mutedText)
                                    Text("Day \(person.summary.mostAdvancedDay)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Last active")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mutedText)
                                    Text(relativeDate(person.summary.lastActiveAt))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.primaryText)
                                }
                            }

                            if let bio = person.representativeMember.profile?.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.caption)
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(2)
                            }
                        }
                        .cardSurface()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var peopleSummaries: [PersonSummaryEntry] {
        var membersByID: [String: [TogetherMemberContext]] = [:]

        for group in socialService.groups {
            for member in group.members {
                membersByID[member.id, default: []].append(TogetherMemberContext(member: member, groupID: group.id))
            }
        }

        let entries = membersByID.compactMap { memberID, contexts -> PersonSummaryEntry? in
            guard let representative = contexts.sorted(by: {
                ($0.member.lastActiveAt ?? .distantPast) > ($1.member.lastActiveAt ?? .distantPast)
            }).first?.member else {
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
            switch peopleSortOption {
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

    private var peopleStatsRow: some View {
        HStack(spacing: 12) {
            peopleStatPill(label: "People", value: "\(peopleSummaries.count)")
            peopleStatPill(label: "Active today", value: "\(activeTodayCount)")
            peopleStatPill(label: "Shared plans", value: "\(socialService.groups.count)")
        }
    }

    private func peopleStatPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.mutedText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var activeTodayCount: Int {
        let calendar = Calendar.current
        return peopleSummaries.reduce(into: 0) { count, entry in
            if let date = entry.summary.lastActiveAt, calendar.isDateInToday(date) {
                count += 1
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentMoss)

            Text("No shared plans yet")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text("Start a plan and invite others to memorize together. Everyone works at their own pace, and you can see each other's progress.")
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)

            if appModel.activePlan != nil {
                Button("Invite people to this plan") {
                    Task { await shareActivePlan() }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Pick a plan first") {
                    appModel.openPlans()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .cardSurface()
    }

    // MARK: - Group Card

    private func groupCard(_ group: SharedPlanGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: group.planSystemImage)
                    .foregroundStyle(Color.accentMoss)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.planTitle)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                    Text("\(group.members.count) \(group.members.count == 1 ? "person" : "people") • \(group.planDuration) days")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                    syncMetaText(for: group.id)
                }
                Spacer()
                if isOwner(group) {
                    Button {
                        Task {
                            guard await checkIdentityForCloudAction("send invite") else { return }
                            sharingGroup = group
                        }
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color.accentMoss)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(group.members) { member in
                memberRow(member, duration: group.planDuration)
            }

            HStack(spacing: 12) {
                Button("View") {
                    selectedGroup = group
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))

                Button("Sync") {
                    Task { await syncProgress(for: group) }
                }
                .buttonStyle(FilledSoftButtonStyle())
            }

            syncStateRow(for: group)

            if !isOwner(group) {
                Button(role: .destructive) {
                    pendingLeaveGroup = group
                } label: {
                    Text("Leave plan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }
        }
        .cardSurface()
    }

    // MARK: - Member Row

    private func memberRow(_ member: PlanMembership, duration: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProfileAvatarView(member: member, size: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(member.profile?.displayName ?? member.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)

                    HStack(spacing: 6) {
                        let isComplete = member.completedDays.count >= duration
                        Text(isComplete ? "Complete" : "Day \(member.currentDay)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isComplete ? Color.accentMoss : Color.accentGold)

                        if member.streak > 1 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.accentGold)
                                Text("\(member.streak)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.mutedText)
                            }
                        }

                        if let lastActive = member.lastActiveAt {
                            Text(relativeDate(lastActive))
                                .font(.caption2)
                                .foregroundStyle(Color.mutedText)
                        }
                    }

                    if let preview = profilePreviewLine(for: member) {
                        Text(preview)
                            .font(.caption2)
                            .foregroundStyle(Color.mutedText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text("\(member.completedDays.count)/\(duration)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentMoss)
            }

            // Day dots
            dayDots(member: member, duration: duration)
        }
    }

    private func profilePreviewLine(for member: PlanMembership) -> String? {
        if let bio = member.profile?.bio, !bio.isEmpty {
            return bio
        }
        if let verse = member.profile?.favoriteVerse, !verse.isEmpty {
            return "Loves: \(verse)"
        }
        return nil
    }

    private func dayDots(member: PlanMembership, duration: Int) -> some View {
        let maxDots = min(duration, 30)
        return HStack(spacing: 2) {
            ForEach(1...maxDots, id: \.self) { day in
                Circle()
                    .fill(
                        member.completedDays.contains(day)
                            ? Color.accentMoss
                            : day == member.currentDay
                                ? Color.accentGold
                                : Color.mutedText.opacity(0.15)
                    )
                    .frame(width: 8, height: 8)
            }
            if duration > 30 {
                Text("+\(duration - 30)")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.mutedText)
            }
        }
    }

    // MARK: - Actions

    private func shareActivePlan() async {
        guard await checkIdentityForCloudAction("share this plan") else { return }
        guard let plan = appModel.activePlan else { return }
        let share = await socialService.createSharedPlan(
            planID: plan.id,
            planTitle: plan.title,
            planDuration: plan.duration,
            planSystemImage: plan.systemImageName,
            ownerName: appModel.userDisplayName,
            ownerEnrollment: appModel.activePlanEnrollment,
            ownerStreak: appModel.currentStreak
        )
        if share != nil, let group = socialService.groups.first {
            sharingGroup = group
            cloudActionError = nil
        }
    }

    private func syncProgress(for group: SharedPlanGroup) async {
        guard await checkIdentityForCloudAction("sync progress") else { return }
        // If not enrolled, enroll first
        if appModel.activePlanEnrollment?.planID != group.planID {
            if let plan = BuiltInPlans.plan(withID: group.planID) ?? appModel.customPlans.first(where: { $0.id == group.planID }) {
                appModel.enrollInPlan(plan)
            }
        }

        guard let enrollment = appModel.activePlanEnrollment, enrollment.planID == group.planID else { return }

        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: group.zoneOwnerName)
        _ = await socialService.syncMyProgress(
            groupZoneID: zoneID,
            memberName: appModel.userDisplayName,
            currentDay: enrollment.currentDay,
            completedDays: enrollment.completedDays,
            streak: appModel.currentStreak
        )
        await socialService.fetchGroups()
        cloudActionError = nil
    }

    private func isOwner(_ group: SharedPlanGroup) -> Bool {
        socialService.isOwner(of: group, currentMemberID: currentMemberID, currentDisplayName: appModel.userDisplayName)
    }

    private var presentableError: String? {
        if let cloudActionError {
            return cloudActionError
        }

        if let error = socialService.lastError {
            if errorIndicatesIdentityIssue(error) {
                return iCloudUnavailableMessage
            }
            return error
        }
        return nil
    }

    private var iCloudUnavailableMessage: String {
        switch identityStatus {
        case .available:
            return "iCloud is required for invites and sync. Please try again."
        case .unavailable:
            return "iCloud is unavailable. Sign in to iCloud in Settings to invite people and sync shared plans."
        case .restricted:
            return "iCloud access is restricted on this device. Invites and sync are unavailable until iCloud is enabled."
        }
    }

    private func checkIdentityForCloudAction(_ action: String) async -> Bool {
        await refreshIdentity()
        guard identityStatus == .available else {
            cloudActionError = "Can't \(action) right now. \(iCloudUnavailableMessage)"
            return false
        }
        cloudActionError = nil
        return true
    }

    private func refreshIdentity() async {
        identityStatus = await socialService.identityStatus()
    }

    private func errorIndicatesIdentityIssue(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("not authenticated")
            || lowercased.contains("icloud")
            || lowercased.contains("no account")
            || lowercased.contains("permission")
            || lowercased.contains("restricted")
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date else { return "No activity yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    @ViewBuilder
    private func syncMetaText(for groupID: String) -> some View {
        if let syncedAt = latestSyncedAt(for: groupID) {
            Text("Last synced \(relativeDate(syncedAt))")
                .font(.caption2)
                .foregroundStyle(Color.mutedText)
        } else {
            Text("Last synced: not yet")
                .font(.caption2)
                .foregroundStyle(Color.mutedText)
        }
    }

    @ViewBuilder
    private func syncStateRow(for group: SharedPlanGroup) -> some View {
        let state = socialService.syncStateByGroupID[group.id] ?? .idle
        switch state {
        case .idle:
            EmptyView()
        case .syncing:
            Label("Syncing now…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(Color.mutedText)
        case .success(let syncedAt):
            Label("Synced \(relativeDate(syncedAt))", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.accentMoss)
        case .failure(let reason):
            HStack(spacing: 8) {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("Retry") { Task { await syncProgress(for: group) } }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentMoss)
            }
        }
    }

    private func latestSyncedAt(for groupID: String) -> Date? {
        if case .success(let date) = socialService.syncStateByGroupID[groupID] {
            return date
        }
        return nil
    }
}

private struct PersonSummaryEntry: Identifiable {
    var id: String { summary.id }
    let summary: PersonSummary
    let representativeMember: PlanMembership
}

private struct TogetherMemberContext {
    let member: PlanMembership
    let groupID: String
}

// MARK: - Shared Plan Detail

struct SharedPlanDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let group: SharedPlanGroup
    let socialService: SocialService

    @State private var sharingGroup: SharedPlanGroup?
    @State private var currentMemberID: String?
    @State private var showLeaveConfirm = false
    @State private var showArchiveConfirm = false
    @State private var actionMessage: String?
    @State private var identityStatus: SharedPlanManager.IdentityStatus = .unavailable
    @State private var cloudActionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                planHeader
                collaborationScopeCard
                myProgressSection
                membersSection
                actionsSection
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .navigationTitle(group.planTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $sharingGroup) { group in
            PlanCloudSharingSheet(group: group)
        }
        .task {
            currentMemberID = await socialService.stableMemberID()
        }
        .confirmationDialog("Leave shared plan?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave Plan", role: .destructive) {
                Task {
                    let feedback = await socialService.leaveGroup(group, currentDisplayName: appModel.userDisplayName)
                    actionMessage = feedback.message
                    if feedback.success { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll stop receiving progress updates for this group.")
        }
        .confirmationDialog("Archive and stop sharing?", isPresented: $showArchiveConfirm, titleVisibility: .visible) {
            Button("Archive Group", role: .destructive) {
                Task {
                    let feedback = await socialService.leaveGroup(group, currentDisplayName: appModel.userDisplayName)
                    actionMessage = feedback.message
                    if feedback.success { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the shared group for everyone and stops future syncing.")
        }
        .alert("Shared Plan", isPresented: Binding(
            get: { actionMessage != nil },
            set: { if !$0 { actionMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionMessage ?? "")
        }
        .task {
            identityStatus = await socialService.identityStatus()
        }
    }

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: group.planSystemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentMoss)
                Spacer()
                Text("Started by \(group.ownerName)")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            Text(group.planTitle)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Color.primaryText)

            HStack(spacing: 12) {
                StatusPill(title: "\(group.planDuration) days")
                StatusPill(title: "\(group.members.count) people", tint: .accentGold)
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private var collaborationScopeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How collaboration works")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text("Only people invited to this plan can see each other's progress.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)
        }
        .cardSurface()
    }

    @ViewBuilder
    private var myProgressSection: some View {
        if let enrollment = appModel.activePlanEnrollment, enrollment.planID == group.planID {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your progress")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)

                ProgressView(value: Double(enrollment.completedDays.count), total: Double(group.planDuration))
                    .tint(Color.accentMoss)

                Text("Day \(enrollment.currentDay) of \(group.planDuration) • \(enrollment.completedDays.count) days complete")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }
            .cardSurface()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("You're not on this plan yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryText)

                if let plan = BuiltInPlans.plan(withID: group.planID) ?? appModel.customPlans.first(where: { $0.id == group.planID }) {
                    Button("Join \(plan.title)") {
                        appModel.enrollInPlan(plan)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .cardSurface()
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("People")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            ForEach(group.members) { member in
                memberCard(member)
            }
        }
    }

    private func memberCard(_ member: PlanMembership) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ProfileAvatarView(member: member, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(member.profile?.displayName ?? member.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        if member.displayName == appModel.userDisplayName {
                            Text("(you)")
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                        }
                    }

                    let isComplete = member.completedDays.count >= group.planDuration
                    Text(isComplete ? "Plan complete" : "Day \(member.currentDay) of \(group.planDuration)")
                        .font(.caption)
                        .foregroundStyle(isComplete ? Color.accentMoss : Color.mutedText)
                }

                Spacer()

                if member.streak > 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.accentGold)
                        Text("\(member.streak)-day")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.mutedText)
                    }
                }
            }

            ProgressView(value: Double(member.completedDays.count), total: Double(group.planDuration))
                .tint(Color.accentMoss)

            // Day dots — larger for detail view
            HStack(spacing: 3) {
                ForEach(1...min(group.planDuration, 30), id: \.self) { day in
                    Circle()
                        .fill(
                            member.completedDays.contains(day)
                                ? Color.accentMoss
                                : day == member.currentDay
                                    ? Color.accentGold
                                    : Color.mutedText.opacity(0.15)
                        )
                        .frame(width: 10, height: 10)
                }
                if group.planDuration > 30 {
                    Text("+\(group.planDuration - 30)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.mutedText)
                }
            }

            if let lastActive = member.lastActiveAt {
                let formatter = RelativeDateTimeFormatter()
                Text("Active \(formatter.localizedString(for: lastActive, relativeTo: .now))")
                    .font(.caption2)
                    .foregroundStyle(Color.mutedText)
            }

            if let verse = member.profile?.favoriteVerse, !verse.isEmpty {
                Text("Favorite verse: \(verse)")
                    .font(.caption2)
                    .foregroundStyle(Color.mutedText)
            }
        }
        .cardSurface()
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(syncButtonTitle) {
                    Task { await syncProgress() }
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                .disabled(isSyncing)

                if isOwner {
                    Button("Manage members") {
                        Task {
                            await refreshIdentity()
                            guard identityStatus == .available else {
                                cloudActionError = "Can't send invite right now. \(unavailableMessage)"
                                return
                            }
                            sharingGroup = group
                            cloudActionError = nil
                        }
                    }
                    .buttonStyle(FilledSoftButtonStyle())
                }
            }

            if isOwner {
                Button(role: .destructive) {
                    showArchiveConfirm = true
                } label: {
                    Text("Archive / Stop sharing")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            } else {
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Text("Leave plan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }

            Text("Syncing shares your current day and streak with everyone in this plan.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)

            syncStateFooter

            if let cloudActionError {
                Text(cloudActionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func syncProgress() async {
        await refreshIdentity()
        guard identityStatus == .available else {
            cloudActionError = "Can't sync progress right now. \(unavailableMessage)"
            return
        }
        guard let enrollment = appModel.activePlanEnrollment, enrollment.planID == group.planID else { return }
        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: group.zoneOwnerName)
        _ = await socialService.syncMyProgress(
            groupZoneID: zoneID,
            memberName: appModel.userDisplayName,
            currentDay: enrollment.currentDay,
            completedDays: enrollment.completedDays,
            streak: appModel.currentStreak
        )
        await socialService.fetchGroups()
        cloudActionError = nil
    }

    private var syncButtonTitle: String {
        switch socialService.syncStateByGroupID[group.id] ?? .idle {
        case .syncing:
            return "Syncing..."
        default:
            return "Sync my progress"
        }
    }

    private var isSyncing: Bool {
        if case .syncing = socialService.syncStateByGroupID[group.id] ?? .idle {
            return true
        }
        return false
    }

    @ViewBuilder
    private var syncStateFooter: some View {
        let state = socialService.syncStateByGroupID[group.id] ?? .idle
        switch state {
        case .idle:
            if let date = latestSyncedAt {
                Text("Last synced \(relativeDate(date)).")
                    .font(.caption2)
                    .foregroundStyle(Color.mutedText)
            } else {
                Text("Last synced: not yet.")
                    .font(.caption2)
                    .foregroundStyle(Color.mutedText)
            }
        case .syncing:
            Label("Syncing in progress…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .foregroundStyle(Color.mutedText)
        case .success(let date):
            Label("Sync complete \(relativeDate(date)).", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(Color.accentMoss)
        case .failure(let message):
            VStack(alignment: .leading, spacing: 4) {
                Label(message, systemImage: "xmark.octagon.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Button("Retry sync") {
                    Task { await syncProgress() }
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentMoss)
            }
        }
    }

    private var latestSyncedAt: Date? {
        if case .success(let date) = socialService.syncStateByGroupID[group.id] {
            return date
        }
        return nil
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private var isOwner: Bool {
        socialService.isOwner(of: group, currentMemberID: currentMemberID, currentDisplayName: appModel.userDisplayName)
    }

    private var unavailableMessage: String {
        switch identityStatus {
        case .available:
            return "iCloud is required for shared plan sync."
        case .unavailable:
            return "Sign in to iCloud to use invite and sync for shared plans."
        case .restricted:
            return "iCloud access is restricted on this device, so invite and sync are unavailable."
        }
    }

    private func refreshIdentity() async {
        identityStatus = await socialService.identityStatus()
    }
}

// MARK: - Cloud Sharing Sheet

struct ProfileAvatarView: View {
    let member: PlanMembership
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.accentMoss.opacity(0.15))
            .frame(width: size, height: size)
            .overlay {
                Text(String((member.profile?.displayName ?? member.displayName).prefix(1)).uppercased())
                    .font(.system(size: max(12, size * 0.36), weight: .bold))
                    .foregroundStyle(Color.accentMoss)
            }
    }
}

struct PersonDetailView: View {
    let member: PlanMembership
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ProfileAvatarView(member: member, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.profile?.displayName ?? member.displayName)
                            .font(.title3.weight(.semibold))
                        Text("Day \(member.currentDay) • \(member.streak)-day streak")
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                    }
                }
                .cardSurface()

                if let bio = member.profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .cardSurface()
                }
                if let verse = member.profile?.favoriteVerse, !verse.isEmpty {
                    Text("Favorite verse: \(verse)")
                        .font(.subheadline)
                        .cardSurface()
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .navigationTitle("Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct PlanCloudSharingSheet: UIViewControllerRepresentable {
    let group: SharedPlanGroup

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let container = CKContainer(identifier: SharedPlanManager.containerID)
        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: group.zoneOwnerName)
        let recordID = CKRecord.ID(recordName: "plan", zoneID: zoneID)

        let controller = UICloudSharingController { _, prepareHandler in
            Task {
                do {
                    let record = try await container.privateCloudDatabase.record(for: recordID)
                    let share = CKShare(rootRecord: record)
                    share[CKShare.SystemFieldKey.title] = "Join \(group.planTitle) on Hide the Word" as CKRecordValue
                    share.publicPermission = .readWrite

                    let op = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
                    op.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success: prepareHandler(share, container, nil)
                        case .failure(let error): prepareHandler(nil, nil, error)
                        }
                    }
                    container.privateCloudDatabase.add(op)
                } catch {
                    prepareHandler(nil, nil, error)
                }
            }
        }
        controller.availablePermissions = [.allowReadWrite, .allowPrivate] as UICloudSharingController.PermissionOptions
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
