import SwiftUI
import ScriptureMemory

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var didAppear = false
    @State private var showLeavePlanConfirmation = false
    @State private var showSkipDayConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                todayCard
                planCard
                metricsRow
                if appModel.startedVerseCount > 0 {
                    masteryCard
                }
                if !appModel.recentReviewEvents.isEmpty {
                    recentActivityCard
                } else if appModel.startedVerseCount > 0 {
                    EmptyStateView(
                        systemImage: "clock",
                        headline: "No reviews yet",
                        bodyText: "Complete your first session and your activity will appear here.",
                        ctaTitle: "Start today's session",
                        ctaAction: { appModel.startOrResumeSession() }
                    )
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .onAppear { didAppear = true }
        .confirmationDialog("Leave this plan?", isPresented: $showLeavePlanConfirmation, titleVisibility: .visible) {
            Button("Leave plan", role: .destructive) { appModel.leavePlan() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be lost. You can restart the plan anytime.")
        }
        .confirmationDialog("Skip to the next day?", isPresented: $showSkipDayConfirmation, titleVisibility: .visible) {
            Button("Skip") { appModel.advancePlanDay() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This rest day will be marked complete.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appModel.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(heroGreeting)
                .font(.system(.title, design: .serif, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color.primaryText)

            Text(heroSubtitle)
                .font(.body)
                .foregroundStyle(Color.mutedText)
        }
        .offset(y: didAppear ? 0 : 10)
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.35), value: didAppear)
    }

    private var heroGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        default: return "Good evening."
        }
    }

    private var heroSubtitle: String {
        if appModel.currentStreak > 2 {
            return "\(appModel.currentStreak) days in a row. Keep going."
        }
        if appModel.dueReviewCount > 0 {
            return "\(appModel.dueReviewCount) \(appModel.dueReviewCount == 1 ? "verse" : "verses") waiting for you."
        }
        return "A few quiet minutes with the Word."
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appModel.hasDraftSession ? "Resume" : "Today")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(todaySummary)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Color.primaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(appModel.preferredTranslation.shortName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentMoss)
                    Text(appModel.sessionSizePreset.title)
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }
            }

            schedulePills

            if let draftProgressSummary = appModel.draftProgressSummary {
                Text(draftProgressSummary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primaryText)
            }

            Button {
                primaryAction()
            } label: {
                Text(primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            if let preferredTranslationStatusText = appModel.preferredTranslationStatusText {
                Text(preferredTranslationStatusText)
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            if appModel.currentPlanDay?.goal == .rest, !appModel.hasDraftSession {
                Button("Skip to next day") {
                    showSkipDayConfirmation = true
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            } else if appModel.hasDraftSession {
                Button("Start fresh") {
                    appModel.startFreshSession()
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            } else if appModel.activePlanEnrollment == nil, appModel.selectedCollectionID == BuiltInContent.myVersesSetID {
                Button("Open Bible Library", action: appModel.openVerseLibrary)
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }
        }
        .cardSurface()
        .offset(y: didAppear ? 0 : 12)
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.35).delay(0.03), value: didAppear)
    }

    @ViewBuilder
    private var planCard: some View {
        if let plan = appModel.activePlan, let enrollment = appModel.activePlanEnrollment {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: plan.systemImageName)
                        .foregroundStyle(Color.accentMoss)
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Text(appModel.planDayProgress ?? "Plan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(appModel.isActivePlanComplete ? Color.accentMoss : Color.accentGold)
                }

                ProgressView(value: Double(enrollment.completedDays.count), total: Double(plan.duration))
                    .tint(Color.accentMoss)

                if let day = appModel.currentPlanDay {
                    Text(day.title)
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                } else if appModel.isActivePlanComplete {
                    Text("Plan complete! Your verses stay in daily review. Start another plan or keep reviewing at your own pace.")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }

                if appModel.isActivePlanComplete {
                    HStack(spacing: 12) {
                        Button("Browse plans") {
                            appModel.openPlans()
                        }
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true))

                        Button("Leave plan") {
                            showLeavePlanConfirmation = true
                        }
                        .buttonStyle(FilledSoftButtonStyle())
                    }
                } else {
                    HStack(spacing: 12) {
                        Button("View plan") {
                            appModel.openPlans()
                        }
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true))

                        if let image = renderPlanShareImage(
                            plan: plan,
                            currentDay: enrollment.currentDay,
                            completedDays: enrollment.completedDays.count
                        ) {
                            ShareLink(
                                item: Image(uiImage: image),
                                preview: SharePreview(plan.title, image: Image(uiImage: image))
                            ) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                        }
                    }
                }
            }
            .cardSurface()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: appModel.selectedCollection.systemImageName)
                        .foregroundStyle(Color.accentGold)
                    Text("Free Study")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Text(appModel.selectedCollection.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentMoss)
                }

                Text("Studying \(appModel.activeCollectionCountLabel) at your own pace with spaced repetition.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)

                Button("Browse plans") {
                    appModel.openPlans()
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }
            .cardSurface()
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 16) {
            if appModel.activePlan != nil {
                metricCard(
                    title: "Started",
                    value: "\(appModel.startedVerseCount)",
                    detail: startedDetail
                )
                metricCard(
                    title: "Due",
                    value: "\(appModel.dueReviewCount)",
                    detail: appModel.dueReviewCount == 0 ? "All caught up" : "Ready for review"
                )
            } else {
                metricCard(
                    title: appModel.selectedCollectionID == BuiltInContent.myVersesSetID ? "Practice" : "Started",
                    value: appModel.selectedCollectionID == BuiltInContent.myVersesSetID ? "\(appModel.practiceOnlyCustomStudyUnits.count)" : "\(appModel.startedVerseCount)",
                    detail: appModel.selectedCollectionID == BuiltInContent.myVersesSetID ? practiceDetail : startedDetail
                )
                metricCard(
                    title: "Due",
                    value: "\(appModel.dueReviewCount)",
                    detail: appModel.dueReviewCount == 0 ? "All caught up" : "Ready for review"
                )
            }
        }
        .animation(.snappy(duration: 0.28), value: appModel.selectedCollectionID)
        .animation(.snappy(duration: 0.28), value: appModel.startedVerseCount)
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primaryText)
                .contentTransition(.opacity)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var masteryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mastery")
                    .font(.headline)
                Spacer()
                if let image = renderWeeklyProgressImage(data: appModel.weeklyProgressData) {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("Weekly Progress", image: Image(uiImage: image))
                    ) {
                        Label("Share week", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            let counts = appModel.masteryTierCounts
            HStack(spacing: 12) {
                ForEach(MasteryTier.allCases, id: \.self) { tier in
                    let count = counts[tier, default: 0]
                    VStack(spacing: 4) {
                        Image(systemName: tier.systemImage)
                            .font(.title3)
                        Text("\(count)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                            .contentTransition(.numericText())
                        Text(tier.title)
                            .font(.caption2)
                            .foregroundStyle(Color.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if appModel.currentStreak > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.accentGold)
                        .font(.caption)
                    Text("\(appModel.currentStreak)-day streak")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                }
            }
        }
        .cardSurface()
        .animation(.snappy(duration: 0.28), value: appModel.masteryTierCounts.values.map { $0 })
    }

    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.headline)

            ForEach(Array(appModel.recentReviewEvents.prefix(3)), id: \.id) { event in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(color(for: event.rating))
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.unitReference)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Text(activityLine(for: event))
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                    }

                    Spacer()
                }
                .contextMenu {
                    if let unit = appModel.studyUnit(withID: event.unitID) {
                        Button {
                            appModel.startFocusedPractice(for: unit)
                        } label: {
                            Label("Practice now", systemImage: "arrow.trianglehead.2.counterclockwise")
                        }
                    }
                }
            }

            Button("Open journey", action: appModel.openJourney)
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
        }
        .cardSurface()
        .animation(.snappy(duration: 0.28), value: appModel.recentReviewEvents.count)
    }

    private var schedulePills: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                schedulePillItems
            }
            VStack(alignment: .leading, spacing: 8) {
                schedulePillItems
            }
        }
    }

    private var schedulePillItems: some View {
        Group {
            if appModel.draftSession?.isFocusedPractice == true {
                StatusPill(title: "Focused practice", tint: .accentGold)
                StatusPill(title: appModel.draftCollectionDisplayName)
                StatusPill(title: "Saved progress", tint: .accentMoss)
            } else if let plan = appModel.activePlan, let day = appModel.currentPlanDay {
                StatusPill(title: plan.title, tint: .accentGold)
                StatusPill(title: "Day \(day.dayNumber)")
                StatusPill(title: planGoalLabel(day.goal), tint: .accentMoss)
            } else {
                StatusPill(title: "Free study", tint: .accentGold)
                StatusPill(title: dueReviewLabel)
                StatusPill(title: newUnitLabel, tint: .accentMoss)
            }
        }
    }

    private func activityLine(for event: ReviewEvent) -> String {
        "\(event.kind == .restudy ? "Restudied" : "Reviewed") \(relativeDateString(for: event.reviewedAt)) • \(event.rating.rawValue.capitalized)"
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func color(for rating: ReviewRating) -> Color {
        switch rating {
        case .easy:
            return .accentMoss
        case .medium:
            return .accentGold
        case .hard:
            return .red.opacity(0.7)
        }
    }

    private var todaySummary: String {
        if appModel.hasDraftSession {
            if appModel.draftSession?.isFocusedPractice == true {
                return "Return to focused practice in \(appModel.draftCollectionDisplayName)."
            }
            if let planContext = appModel.draftSession?.planContext {
                return "Pick up \(planContext.planTitle), day \(planContext.dayNumber): \(planContext.dayTitle)."
            }
            return "Pick up where you left off in \(appModel.draftCollectionDisplayName)."
        }

        if appModel.activePlanEnrollment == nil, appModel.selectedCollectionID == BuiltInContent.myVersesSetID, appModel.activeVerses.isEmpty {
            return "Pick a plan or add verses to get started."
        }

        if let plan = appModel.activePlan, let day = appModel.currentPlanDay {
            switch day.goal {
            case .learnNew:
                return "Continue \(plan.title) with \(day.title) and any due review from earlier days."
            case .fullRecall:
                return "Use today to recall \(day.title) as one connected passage."
            case .reviewOnly:
                return "Strengthen what you’ve already started in \(plan.title)."
            case .rest:
                return "Keep a light touch today. A short review is ready if you want it."
            }
        }

        let reviewCount = appModel.sessionPlan.items.filter { $0.kind == .review }.count
        let hasNewVerse = appModel.sessionPlan.includesNewVerse
        let reviewLabel = reviewCount == 1 ? "verse" : "verses"

        if reviewCount == 0 && !hasNewVerse {
            return "You’re caught up. A light review is ready whenever you return."
        }

        if hasNewVerse {
            return "Review \(reviewCount) \(reviewLabel) and take in 1 new verse."
        }

        return "Review \(reviewCount) \(reviewLabel) in a short focused block."
    }

    private var primaryActionTitle: String {
        if appModel.hasDraftSession {
            if appModel.draftSession?.isFocusedPractice == true {
                return "Resume focused practice"
            }
            if let planContext = appModel.draftSession?.planContext {
                return "Resume day \(planContext.dayNumber)"
            }
            return "Resume session"
        }

        if appModel.activePlanEnrollment == nil, appModel.selectedCollectionID == BuiltInContent.myVersesSetID, appModel.activeVerses.isEmpty {
            return "Browse plans"
        }

        if let day = appModel.currentPlanDay, appModel.activePlan != nil {
            if day.goal == .rest {
                return "Light review"
            }
            return "Start day \(day.dayNumber)"
        }

        return "Start today’s session"
    }

    private var dueReviewLabel: String {
        if appModel.dueReviewCount == 0 {
            return "No reviews due"
        }
        let label = appModel.dueReviewCount == 1 ? "review due" : "reviews due"
        return "\(appModel.dueReviewCount) \(label)"
    }

    private var newUnitLabel: String {
        switch appModel.queuedNewUnitCount {
        case 0:
            return "No new unit queued"
        case 1:
            return "1 new unit queued"
        default:
            return "\(appModel.queuedNewUnitCount) new units queued"
        }
    }

    private var practiceDetail: String {
        if appModel.practiceOnlyCustomStudyUnits.isEmpty {
            return "No practice-only units"
        }
        let count = appModel.practiceOnlyCustomStudyUnits.count
        return "\(count) kept outside the daily queue"
    }

    private func planGoalLabel(_ goal: PlanDayGoal) -> String {
        switch goal {
        case .learnNew:
            return "New material"
        case .reviewOnly:
            return "Review day"
        case .fullRecall:
            return "Full recall"
        case .rest:
            return "Rest day"
        }
    }

    private func primaryAction() {
        if appModel.activePlanEnrollment == nil, appModel.selectedCollectionID == BuiltInContent.myVersesSetID, appModel.activeVerses.isEmpty {
            appModel.openPlans()
            return
        }

        appModel.startOrResumeSession()
    }

    private var startedDetail: String {
        if let nextReviewDate = appModel.nextReviewDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return "Next \(formatter.localizedString(for: nextReviewDate, relativeTo: .now))"
        }

        return "No review history yet"
    }
}

#Preview("Home · Default") {
    HomeView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
}

#Preview("Home · XXXL") {
    HomeView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
        .dynamicTypeSize(.xxxLarge)
}

#Preview("Home · AX Medium") {
    HomeView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
        .dynamicTypeSize(.accessibility2)
}

#Preview("Home · AX XL") {
    HomeView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
        .dynamicTypeSize(.accessibility3)
}
