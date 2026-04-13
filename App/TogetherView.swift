import SwiftUI
import ScriptureMemory
import CloudKit

struct TogetherView: View {
    @Environment(AppModel.self) private var appModel
    @State private var planManager = SharedPlanManager()
    @State private var selectedGroup: SharedPlanGroup?
    @State private var sharingGroup: SharedPlanGroup?
    @State private var identityStatus: SharedPlanManager.IdentityStatus = .unavailable
    @State private var cloudActionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if planManager.isLoading, planManager.groups.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if planManager.groups.isEmpty {
                    emptyState
                } else {
                    ForEach(planManager.groups) { group in
                        groupCard(group)
                    }
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
            await planManager.fetchGroups()
        }
        .refreshable {
            await refreshIdentity()
            await planManager.fetchGroups()
        }
        .sheet(item: $selectedGroup) { group in
            NavigationStack {
                SharedPlanDetailView(group: group, planManager: planManager)
            }
        }
        .sheet(item: $sharingGroup) { group in
            PlanCloudSharingSheet(group: group, planManager: planManager)
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

            Text("Share a plan with friends. Same plan, your own pace, mutual encouragement.")
                .font(.body)
                .foregroundStyle(Color.mutedText)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentMoss)

            Text("No shared plans yet")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text("Start a plan and share it with a friend. You'll each work at your own pace and see where everyone is day by day.")
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)

            if appModel.activePlan != nil {
                Button("Share your active plan") {
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
                }
                Spacer()
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
        }
        .cardSurface()
    }

    // MARK: - Member Row

    private func memberRow(_ member: SharedPlanMember, duration: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color.accentMoss.opacity(0.15))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Text(String(member.displayName.prefix(1)).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentMoss)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(member.displayName)
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

    private func dayDots(member: SharedPlanMember, duration: Int) -> some View {
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
        let share = await planManager.createSharedPlan(
            planID: plan.id,
            planTitle: plan.title,
            planDuration: plan.duration,
            planSystemImage: plan.systemImageName,
            ownerName: appModel.userDisplayName,
            ownerEnrollment: appModel.activePlanEnrollment,
            ownerStreak: appModel.currentStreak
        )
        if share != nil, let group = planManager.groups.first {
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

        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: CKCurrentUserDefaultName)
        await planManager.syncMyProgress(
            groupZoneID: zoneID,
            memberName: appModel.userDisplayName,
            currentDay: enrollment.currentDay,
            completedDays: enrollment.completedDays,
            streak: appModel.currentStreak
        )
        await planManager.fetchGroups()
        cloudActionError = nil
    }

    private var presentableError: String? {
        if let cloudActionError {
            return cloudActionError
        }

        if let error = planManager.lastError {
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
            return "iCloud is unavailable. Sign in to iCloud in Settings to invite friends and sync shared plans."
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
        identityStatus = await planManager.identityStatus()
    }

    private func errorIndicatesIdentityIssue(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("not authenticated")
            || lowercased.contains("icloud")
            || lowercased.contains("no account")
            || lowercased.contains("permission")
            || lowercased.contains("restricted")
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

// MARK: - Shared Plan Detail

struct SharedPlanDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let group: SharedPlanGroup
    let planManager: SharedPlanManager

    @State private var isSyncing = false
    @State private var sharingGroup: SharedPlanGroup?
    @State private var identityStatus: SharedPlanManager.IdentityStatus = .unavailable
    @State private var cloudActionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                planHeader
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
            PlanCloudSharingSheet(group: group, planManager: planManager)
        }
        .task {
            identityStatus = await planManager.identityStatus()
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
            Text("Everyone's progress")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            ForEach(group.members) { member in
                memberCard(member)
            }
        }
    }

    private func memberCard(_ member: SharedPlanMember) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.accentMoss.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(member.displayName.prefix(1)).uppercased())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.accentMoss)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(member.displayName)
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
        }
        .cardSurface()
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(isSyncing ? "Syncing..." : "Sync my progress") {
                    Task {
                        isSyncing = true
                        await syncProgress()
                        isSyncing = false
                    }
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                .disabled(isSyncing)

                Button("Invite") {
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

            Text("Each person keeps their own progress. Syncing shares your current day so friends can see where you are.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)

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
        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: CKCurrentUserDefaultName)
        await planManager.syncMyProgress(
            groupZoneID: zoneID,
            memberName: appModel.userDisplayName,
            currentDay: enrollment.currentDay,
            completedDays: enrollment.completedDays,
            streak: appModel.currentStreak
        )
        await planManager.fetchGroups()
        cloudActionError = nil
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
        identityStatus = await planManager.identityStatus()
    }
}

// MARK: - Cloud Sharing Sheet

struct PlanCloudSharingSheet: UIViewControllerRepresentable {
    let group: SharedPlanGroup
    let planManager: SharedPlanManager

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let container = CKContainer(identifier: SharedPlanManager.containerID)
        let zoneID = CKRecordZone.ID(zoneName: group.id, ownerName: CKCurrentUserDefaultName)
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
