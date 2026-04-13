import SwiftUI
import ScriptureMemory

struct PlanLibraryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: MemorizationPlan?
    @State private var showingCreatePlan = false
    @State private var showLeavePlanConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let enrollment = appModel.activePlanEnrollment, let plan = appModel.activePlan {
                    activePlanCard(plan, enrollment: enrollment)
                }

                ForEach(PlanCategory.allCases) { category in
                    let plans = BuiltInPlans.allPlans.filter { $0.category == category }
                    if !plans.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.title)
                                .font(.headline)
                                .foregroundStyle(Color.primaryText)

                            ForEach(plans) { plan in
                                planCard(plan)
                            }
                        }
                    }
                }

                if !appModel.customPlans.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Custom")
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)

                        ForEach(appModel.customPlans) { plan in
                            planCard(plan)
                        }
                    }
                }

                freeStudySection
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "plans.nav.title", defaultValue: "Plans", table: "Localizable"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingCreatePlan = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.done", defaultValue: "Done", table: "Localizable")) { dismiss() }
            }
        }
        .sheet(isPresented: $showingCreatePlan) {
            NavigationStack {
                CreatePlanView()
            }
        }
        .sheet(item: $selectedPlan) { plan in
            NavigationStack {
                PlanDetailView(plan: plan)
            }
        }
        .confirmationDialog("Leave this plan?", isPresented: $showLeavePlanConfirmation, titleVisibility: .visible) {
            Button("Leave plan", role: .destructive) { appModel.leavePlan() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be lost. You can restart the plan anytime.")
        }
    }

    private var freeStudySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "plans.free_study.title", defaultValue: "Free Study", table: "Localizable"))
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text(String(localized: "plans.free_study.body", defaultValue: "Study at your own pace with spaced repetition. Pick a collection and the app handles scheduling.", table: "Localizable"))
                .font(.caption)
                .foregroundStyle(Color.mutedText)

            ForEach(BuiltInContent.verseSets, id: \.id) { verseSet in
                Button {
                    appModel.leavePlan()
                    appModel.selectCollection(verseSet.id)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: verseSet.systemImageName)
                            .font(.title2)
                            .foregroundStyle(Color.accentGold)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(verseSet.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                            Text(verseSet.summary)
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                                .lineLimit(1)
                        }

                        Spacer()

                        if appModel.activePlanEnrollment == nil && appModel.selectedCollectionID == verseSet.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentMoss)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                }
                .buttonStyle(ScalableCardButtonStyle())
            }
        }
    }

    private func activePlanCard(_ plan: MemorizationPlan, enrollment: PlanEnrollment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: plan.systemImageName)
                    .foregroundStyle(Color.accentMoss)
                    Text(String(localized: "plans.active.badge", defaultValue: "Active Plan", table: "Localizable"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentMoss)
                Spacer()
                Text(appModel.planDayProgress ?? "Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appModel.isActivePlanComplete ? Color.accentMoss : Color.accentGold)
            }

            Text(plan.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primaryText)

            if let day = appModel.currentPlanDay {
                HStack(spacing: 8) {
                    StatusPill(title: day.title)
                    StatusPill(title: day.goal == .reviewOnly ? "Review day" : day.goal == .fullRecall ? "Full recall" : "New material", tint: .accentGold)
                }
            } else if appModel.isActivePlanComplete {
                Text("Plan completed. Keep the passage in review or move on to another plan.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            ProgressView(value: Double(enrollment.completedDays.count), total: Double(plan.duration))
                .tint(Color.accentMoss)

            Text("\(enrollment.completedDays.count) \(String(localized: "common.of", defaultValue: "of", table: "Localizable")) \(plan.duration) \(String(localized: "unit.day.plural", defaultValue: "days", table: "Localizable")) \(String(localized: "plans.completed", defaultValue: "completed", table: "Localizable"))")
                .font(.caption)
                .foregroundStyle(Color.mutedText)

            if appModel.isActivePlanComplete {
                HStack(spacing: 12) {
                    Button("Leave plan") {
                        showLeavePlanConfirmation = true
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))

                    Button("Start another") {
                        dismiss()
                    }
                    .buttonStyle(FilledSoftButtonStyle())
                }
            }
        }
        .cardSurface()
    }

    private func planCard(_ plan: MemorizationPlan) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: 14) {
                Image(systemName: plan.systemImageName)
                    .font(.title2)
                    .foregroundStyle(Color.accentMoss)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                    Text(planSummary(plan.duration, plan.totalVerseCount))
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }

                Spacer()

                if appModel.activePlanEnrollment?.planID == plan.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentMoss)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(ScalableCardButtonStyle())
    }
}

private func planSummary(_ days: Int, _ verses: Int) -> String {
    let dayLabel = days == 1
        ? String(localized: "unit.day.singular", defaultValue: "day", table: "Localizable")
        : String(localized: "unit.day.plural", defaultValue: "days", table: "Localizable")
    let verseLabel = verses == 1
        ? String(localized: "unit.verse.singular", defaultValue: "verse", table: "Localizable")
        : String(localized: "unit.verse.plural", defaultValue: "verses", table: "Localizable")
    return "\(days) \(dayLabel) • \(verses) \(verseLabel)"
}

struct PlanDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLeavePlanConfirmation = false
    let plan: MemorizationPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: plan.systemImageName)
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentMoss)

                    Text(plan.title)
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.primaryText)

                    Text(plan.description)
                        .font(.body)
                        .foregroundStyle(Color.mutedText)

                    HStack(spacing: 12) {
                        StatusPill(title: "\(plan.duration) days")
                        StatusPill(title: "\(plan.totalVerseCount) verses", tint: .accentGold)
                        StatusPill(title: plan.category.title, tint: .accentMoss)
                    }
                }

                if isEnrolled {
                    Button("Leave this plan") {
                        showLeavePlanConfirmation = true
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                } else {
                    Button("Start this plan") {
                        appModel.enrollInPlan(plan)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if let image = renderPlanShareImage(
                        plan: plan,
                        currentDay: appModel.activePlanEnrollment?.planID == plan.id ? appModel.activePlanEnrollment?.currentDay : nil,
                        completedDays: appModel.activePlanEnrollment?.planID == plan.id ? appModel.activePlanEnrollment?.completedDays.count ?? 0 : 0
                    ) {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(plan.title, image: Image(uiImage: image))
                        ) {
                            Label("Share this plan", systemImage: "person.2")
                        }
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Day-by-day breakdown")
                        .font(.headline)

                    ForEach(plan.days) { day in
                        dayRow(day)
                    }
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .confirmationDialog("Leave this plan?", isPresented: $showLeavePlanConfirmation, titleVisibility: .visible) {
            Button("Leave plan", role: .destructive) {
                appModel.leavePlan()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress will be lost. You can restart the plan anytime.")
        }
    }

    @ViewBuilder
    private func dayRow(_ day: PlanDay) -> some View {
        let completed = appModel.activePlanEnrollment?.completedDays.contains(day.dayNumber) == true
        let isCurrent = appModel.activePlanEnrollment?.currentDay == day.dayNumber && isEnrolled

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(completed ? Color.accentMoss : isCurrent ? Color.accentGold : Color.mutedText.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if completed {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(day.dayNumber)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isCurrent ? .white : Color.mutedText)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(day.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryText)

                    Text(goalLabel(day.goal))
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)

                    if !day.verseReferences.isEmpty, day.goal != .rest {
                        Text("\(day.verseReferences.count) verse\(day.verseReferences.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(Color.accentMoss)
                    }
                }

                Spacer()
            }

            // Show verse text for learn/recall days
            if !day.verseReferences.isEmpty, day.goal != .rest {
                let verseTexts = resolveVerseTexts(day.verseReferences)
                if !verseTexts.isEmpty {
                    Text(verseTexts)
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                        .lineLimit(3)
                        .padding(.leading, 40)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func resolveVerseTexts(_ refs: [VerseReference]) -> String {
        let translation = appModel.preferredTranslation
        return refs.compactMap { ref in
            guard let verse = BibleCatalog.verse(
                bookID: ref.bookID,
                chapter: ref.chapter,
                verse: ref.verse,
                setID: BuiltInContent.myVersesSetID
            ) else { return nil }
            return verse.text(in: translation)
        }
        .joined(separator: " ")
    }

    private func goalLabel(_ goal: PlanDayGoal) -> String {
        switch goal {
        case .learnNew: return "Learn new material"
        case .reviewOnly: return "Review and strengthen"
        case .fullRecall: return "Full passage recall"
        case .rest: return "Rest day"
        }
    }

    private var isEnrolled: Bool {
        appModel.activePlanEnrollment?.planID == plan.id
    }

    private var planShareURL: URL? {
        guard plan.isBuiltIn else { return nil }
        var components = URLComponents()
        components.scheme = "scripturememory"
        components.host = "share"
        components.path = "/plan-enroll"
        components.queryItems = [URLQueryItem(name: "planID", value: plan.id.uuidString)]
        return components.url
    }
}
