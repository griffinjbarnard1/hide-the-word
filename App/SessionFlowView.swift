import SwiftUI
import ScriptureMemory

struct SessionFlowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if appModel.isCustomCollectionEmpty {
                customCollectionEmptyState
            } else if appModel.currentSessionCount == 0 {
                completionEmptyState
            } else if appModel.currentSessionPhase == .complete || appModel.currentSessionIndex >= appModel.currentSessionCount {
                CompletionView(
                    reviewedCount: reviewedCount,
                    newVerseCount: newVerseCount,
                    streak: appModel.currentStreak,
                    milestones: appModel.sessionMilestones,
                    planContext: appModel.draftSession?.planContext,
                    planDuration: appModel.activePlan?.duration,
                    done: appModel.clearCompletedSession
                )
            } else {
                activeStepView
            }
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: appModel.currentSessionPhase)
    }

    @ViewBuilder
    private var activeStepView: some View {
        if let activeItem = appModel.currentSessionItem {
            switch appModel.currentSessionPhase {
            case .display:
                VerseDisplayView(
                    item: activeItem,
                    stepIndex: appModel.currentSessionIndex,
                    totalCount: appModel.currentSessionCount,
                    continueTapped: { appModel.setSessionPhase(.recall) },
                    exitTapped: appModel.leaveSession
                )
            case .recall:
                RecallView(
                    item: activeItem,
                    stepIndex: appModel.currentSessionIndex,
                    totalCount: appModel.currentSessionCount,
                    continueTapped: { appModel.setSessionPhase(.rating) },
                    exitTapped: appModel.leaveSession
                )
                .id(activeItem.unit.id)
            case .rating:
                RatingView(
                    submit: { rating in
                        appModel.completeCurrentReview(rating: rating)
                    }
                )
            case .complete:
                EmptyView()
            }
        } else {
            completionEmptyState
        }
    }

    private var completionEmptyState: some View {
        CompletionView(reviewedCount: 0, newVerseCount: 0, streak: appModel.currentStreak, milestones: [], done: appModel.clearCompletedSession)
    }

    private var customCollectionEmptyState: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("My Verses is empty")
                .font(.system(size: 38, weight: .semibold, design: .serif))
            Text("Add a few verses from the library before starting a custom memorization session.")
                .font(.body)
                .foregroundStyle(Color.mutedText)

            Button("Open Bible Library") {
                appModel.openVerseLibrary()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Back to home", action: appModel.leaveSession)
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))

            Spacer()
        }
        .padding(24)
        .background(Color.screenBackground.ignoresSafeArea())
    }

    private var reviewedCount: Int {
        appModel.draftSession?.items.filter { $0.kind == .review || $0.kind == .restudy }.count ?? 0
    }

    private var newVerseCount: Int {
        appModel.draftSession?.items.filter { $0.kind == .newVerse }.count ?? 0
    }
}

#Preview {
    SessionFlowView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
}
