import SwiftUI
import ScriptureMemory

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var currentPage = 0
    @State private var notificationStatus: NotificationPromptStatus = .pending
    @State private var isOpeningPlans = false

    enum NotificationPromptStatus {
        case pending, granted, denied
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                loopPage.tag(1)
                planPickerPage.tag(2)
                notificationPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .background(Color.screenBackground.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button {
                withAnimation {
                    currentPage = max(currentPage - 1, 0)
                }
            } label: {
                Label(String(localized: "onboarding.nav.back", defaultValue: "Back", table: "Localizable"), systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .opacity(currentPage == 0 ? 0 : 1)
            .disabled(currentPage == 0)
            .accessibilityHidden(currentPage == 0)

            Spacer()

            if currentPage < 3 {
                Button(String(localized: "onboarding.nav.skip", defaultValue: "Skip", table: "Localizable")) {
                    appModel.completeOnboarding()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mutedText)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.closed.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentMoss)

            Text(String(localized: "onboarding.welcome.title", defaultValue: "Hide the Word\nin your heart.", table: "Localizable"))
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primaryText)

            Text(String(localized: "onboarding.welcome.body", defaultValue: "A calm daily system for retaining Scripture through recall, review, and return.", table: "Localizable"))
                .font(.body)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)

            Spacer()

            Button(String(localized: "common.next", defaultValue: "Next", table: "Localizable")) {
                withAnimation { currentPage = 1 }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private var loopPage: some View {
        VStack(spacing: 28) {
            Spacer()

            Text(String(localized: "onboarding.loop.title", defaultValue: "How it works", table: "Localizable"))
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.primaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    stepItem(icon: "eye", title: String(localized: "onboarding.loop.step.read.title", defaultValue: "Read", table: "Localizable"), description: String(localized: "onboarding.loop.step.read.body", defaultValue: "See the full verse", table: "Localizable"))
                    stepItem(icon: "brain.head.profile", title: String(localized: "onboarding.loop.step.recall.title", defaultValue: "Recall", table: "Localizable"), description: String(localized: "onboarding.loop.step.recall.body", defaultValue: "Mask it or type it back", table: "Localizable"))
                    stepItem(icon: "hand.thumbsup", title: String(localized: "onboarding.loop.step.rate.title", defaultValue: "Rate", table: "Localizable"), description: String(localized: "onboarding.loop.step.rate.body", defaultValue: "Easy, medium, or hard", table: "Localizable"))
                }

                VStack(spacing: 16) {
                    stepItem(icon: "eye", title: String(localized: "onboarding.loop.step.read.title", defaultValue: "Read", table: "Localizable"), description: String(localized: "onboarding.loop.step.read.body", defaultValue: "See the full verse", table: "Localizable"))
                    stepItem(icon: "brain.head.profile", title: String(localized: "onboarding.loop.step.recall.title", defaultValue: "Recall", table: "Localizable"), description: String(localized: "onboarding.loop.step.recall.body", defaultValue: "Mask it or type it back", table: "Localizable"))
                    stepItem(icon: "hand.thumbsup", title: String(localized: "onboarding.loop.step.rate.title", defaultValue: "Rate", table: "Localizable"), description: String(localized: "onboarding.loop.step.rate.body", defaultValue: "Easy, medium, or hard", table: "Localizable"))
                }
            }

            Text(String(localized: "onboarding.loop.body", defaultValue: "The app brings verses back at the right time based on your ratings. No penalties for missing a day.", table: "Localizable"))
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)

            Spacer()

            Button(String(localized: "common.next", defaultValue: "Next", table: "Localizable")) {
                withAnimation { currentPage = 2 }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private var planPickerPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(String(localized: "onboarding.plan.title", defaultValue: "Pick a plan\nto begin", table: "Localizable"))
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 32)

                Text(String(localized: "onboarding.plan.body", defaultValue: "Follow a structured plan or study at your own pace. You can change this anytime.", table: "Localizable"))
                    .font(.subheadline)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "onboarding.plan.popular", defaultValue: "Popular Plans", table: "Localizable"))
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    ForEach(BuiltInPlans.allPlans.prefix(4)) { plan in
                        Button {
                            appModel.enrollInPlan(plan)
                            withAnimation { currentPage = 3 }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: plan.systemImageName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.accentMoss)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(plan.title)
                                        .font(.headline)
                                        .foregroundStyle(Color.primaryText)
                                    Text(planSummary(plan.duration, plan.totalVerseCount))
                                        .font(.caption)
                                        .foregroundStyle(Color.mutedText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.mutedText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardSurface()
                        }
                        .buttonStyle(ScalableCardButtonStyle())
                    }
                }

                Button {
                    withAnimation { currentPage = 3 }
                } label: {
                    Text(String(localized: "onboarding.plan.explore_alone", defaultValue: "Explore on my own", table: "Localizable"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentGold)
                }
                .padding(.top, 4)

                Button(String(localized: "onboarding.plan.browse_all", defaultValue: "Browse all plans", table: "Localizable")) {
                    guard !isOpeningPlans else { return }
                    isOpeningPlans = true
                    appModel.completeOnboarding()
                    DispatchQueue.main.async {
                        appModel.openPlans()
                        isOpeningPlans = false
                    }
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                .padding(.top, 2)
                .disabled(isOpeningPlans)
            }
            .padding(32)
        }
    }

    private var notificationPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentGold)

            Text(String(localized: "onboarding.notifications.title", defaultValue: "Stay in rhythm", table: "Localizable"))
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primaryText)

            Text(String(localized: "onboarding.notifications.body", defaultValue: "A gentle daily reminder helps you build a lasting habit. You can change the time or turn it off in Settings.", table: "Localizable"))
                .font(.body)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)

            if notificationStatus == .pending {
                Button(String(localized: "onboarding.notifications.enable", defaultValue: "Turn on reminders", table: "Localizable")) {
                    Task {
                        let granted = await NotificationManager.requestPermission()
                        notificationStatus = granted ? .granted : .denied
                        if granted {
                            appModel.setReminderEnabled(true)
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(String(localized: "common.not_now", defaultValue: "Not now", table: "Localizable")) {
                    appModel.completeOnboarding()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mutedText)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: notificationStatus == .granted ? "checkmark.circle.fill" : "bell.slash")
                        .font(.title2)
                        .foregroundStyle(notificationStatus == .granted ? Color.accentMoss : Color.mutedText)

                    Text(notificationStatus == .granted
                         ? String(localized: "onboarding.notifications.enabled", defaultValue: "Reminders enabled", table: "Localizable")
                         : String(localized: "onboarding.notifications.denied", defaultValue: "No worries — you can enable them in Settings later.", table: "Localizable"))
                        .font(.subheadline)
                        .foregroundStyle(Color.mutedText)
                        .multilineTextAlignment(.center)
                }

                Button(String(localized: "onboarding.finish", defaultValue: "Let's go", table: "Localizable")) {
                    appModel.completeOnboarding()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Spacer()
        }
        .padding(32)
    }

    private func stepItem(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentMoss)
                .frame(width: 52, height: 52)
                .background(Color.accentMoss.opacity(0.1))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primaryText)

            Text(description)
                .font(.caption)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
}
