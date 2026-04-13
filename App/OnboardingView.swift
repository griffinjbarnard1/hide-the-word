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
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .opacity(currentPage == 0 ? 0 : 1)
            .disabled(currentPage == 0)
            .accessibilityHidden(currentPage == 0)

            Spacer()

            if currentPage < 3 {
                Button("Skip") {
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

            Text("Hide the Word\nin your heart.")
                .font(.system(size: 40, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primaryText)

            Text("A calm daily system for retaining Scripture through recall, review, and return.")
                .font(.body)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Next") {
                withAnimation { currentPage = 1 }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private var loopPage: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("How it works")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.primaryText)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    stepItem(icon: "eye", title: "Read", description: "See the full verse")
                    stepItem(icon: "brain.head.profile", title: "Recall", description: "Mask it or type it back")
                    stepItem(icon: "hand.thumbsup", title: "Rate", description: "Easy, medium, or hard")
                }

                VStack(spacing: 16) {
                    stepItem(icon: "eye", title: "Read", description: "See the full verse")
                    stepItem(icon: "brain.head.profile", title: "Recall", description: "Mask it or type it back")
                    stepItem(icon: "hand.thumbsup", title: "Rate", description: "Easy, medium, or hard")
                }
            }

            Text("The app brings verses back at the right time based on your ratings. No penalties for missing a day.")
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Next") {
                withAnimation { currentPage = 2 }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }

    private var planPickerPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Pick a plan\nto begin")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primaryText)
                    .padding(.top, 32)

                Text("Follow a structured plan or study at your own pace. You can change this anytime.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Popular Plans")
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
                                    Text("\(plan.duration) days • \(plan.totalVerseCount) verses")
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
                    Text("Start with free study instead")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentGold)
                }
                .padding(.top, 4)

                Button("Browse all plans") {
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

            Text("Stay in rhythm")
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primaryText)

            Text("A gentle daily reminder helps you build a lasting habit. You can change the time or turn it off in Settings.")
                .font(.body)
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)

            if notificationStatus == .pending {
                Button("Turn on reminders") {
                    Task {
                        let granted = await NotificationManager.requestPermission()
                        notificationStatus = granted ? .granted : .denied
                        if granted {
                            appModel.setReminderEnabled(true)
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Not now") {
                    appModel.completeOnboarding()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mutedText)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: notificationStatus == .granted ? "checkmark.circle.fill" : "bell.slash")
                        .font(.title2)
                        .foregroundStyle(notificationStatus == .granted ? Color.accentMoss : Color.mutedText)

                    Text(notificationStatus == .granted ? "Reminders enabled" : "No worries — you can enable them in Settings later.")
                        .font(.subheadline)
                        .foregroundStyle(Color.mutedText)
                        .multilineTextAlignment(.center)
                }

                Button("Let's go") {
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
}
