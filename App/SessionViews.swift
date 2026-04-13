import StoreKit
import SwiftUI
import ScriptureMemory

struct VerseDisplayView: View {
    @Environment(AppModel.self) private var appModel
    @State private var speechManager = SpeechManager()
    let item: SessionItem
    let stepIndex: Int
    let totalCount: Int
    let continueTapped: () -> Void
    let exitTapped: () -> Void

    var body: some View {
        SessionScaffold(
            title: appModel.activeSessionTitle,
            progressLabel: progressLabel,
            progress: Double(stepIndex + 1) / Double(max(totalCount, 1)),
            bottom: {
                Button("Continue", action: continueTapped)
                    .buttonStyle(PrimaryButtonStyle())
            },
            exitTapped: exitTapped
        ) {
            VStack(alignment: .leading, spacing: 28) {
                if let contextLabel = appModel.studyContextLabel(for: item.unit) {
                    Text(contextLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mutedText)
                }

                Text(item.unit.reference)
                    .font(.headline)
                    .foregroundStyle(Color.accentMoss)

                Text(appModel.displayText(for: item.unit))
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .foregroundStyle(Color.primaryText)

                Text(appModel.preferredTranslation.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mutedText)

                Button {
                    if speechManager.isSpeaking {
                        speechManager.stop()
                    } else {
                        speechManager.speak(appModel.displayText(for: item.unit))
                    }
                } label: {
                    Label(
                        speechManager.isSpeaking ? "Stop" : "Listen",
                        systemImage: speechManager.isSpeaking ? "stop.circle" : "speaker.wave.2"
                    )
                }
                .buttonStyle(SecondaryButtonStyle())

                if let shareImage = renderVerseImage(
                    reference: item.unit.reference,
                    text: appModel.displayText(for: item.unit),
                    translation: appModel.preferredTranslation.displayName
                ) {
                    ShareLink(
                        item: Image(uiImage: shareImage),
                        preview: SharePreview(item.unit.reference, image: Image(uiImage: shareImage))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if appModel.shouldShowESVAttribution(for: item.unit.reference) {
                    ESVAttributionView()
                } else if let translationSupportText = appModel.translationSupportText(for: item.unit.reference) {
                    TranslationSupportView(message: translationSupportText)
                }

                HStack(spacing: 8) {
                    StatusPill(title: item.kind == .newVerse ? "New" : item.kind == .restudy ? "Restudy" : "Review")
                    StatusPill(title: "\(stepIndex + 1) of \(totalCount)", tint: .accentGold)
                    if item.unit.kind == .passage {
                        StatusPill(title: passagePlan.sectionLabel, tint: .accentMoss)
                    }
                }

                Text(contextLine)
                    .font(.body)
                    .foregroundStyle(Color.mutedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()

                if passageSections.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Move through it in sections")
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)

                        HStack(spacing: 8) {
                            StatusPill(title: passagePlan.sectionLabel, tint: .accentGold)
                            StatusPill(title: "\(passagePlan.wordCount) words", tint: .accentMoss)
                        }

                        Text(passagePlan.strategyLine)
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)

                        ForEach(passageSections.prefix(4)) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(section.title) • \(section.reference)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentMoss)
                                if showsSectionTextPreviews {
                                    Text(section.text)
                                        .font(.caption)
                                        .foregroundStyle(Color.mutedText)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .task(id: "\(appModel.preferredTranslation.rawValue)|\(item.unit.reference)") {
            await appModel.prefetchPreferredTranslation(for: item.unit)
        }
        .onChange(of: appModel.currentSessionPhase) {
            speechManager.stop()
        }
    }

    private var contextLine: String {
        switch item.kind {
        case .review:
            return "Read it slowly once, then move into recall."
        case .newVerse:
            return "This is today’s new verse. Take in the wording before recall starts."
        case .restudy:
            return "This one came back for another pass while it is still fresh."
        }
    }

    private var progressLabel: String {
        switch item.kind {
        case .newVerse:
            return "New unit"
        case .restudy:
            return "Restudy \(stepIndex + 1) of \(totalCount)"
        case .review:
            return "Review \(stepIndex + 1) of \(totalCount)"
        }
    }

    private var passageSections: [PassageSection] {
        PassageBreakdown.sections(
            for: appModel.verses(for: item.unit),
            translation: appModel.preferredTranslation == .esv ? .kjv : appModel.preferredTranslation
        )
    }

    private var passagePlan: PassagePlanSummary {
        PassageBreakdown.summary(
            for: appModel.verses(for: item.unit),
            translation: appModel.preferredTranslation == .esv ? .kjv : appModel.preferredTranslation
        )
    }

    private var showsSectionTextPreviews: Bool {
        appModel.preferredTranslation != .esv
    }
}

struct RecallView: View {
    @Environment(AppModel.self) private var appModel
    let item: SessionItem
    let stepIndex: Int
    let totalCount: Int
    let continueTapped: () -> Void
    let exitTapped: () -> Void
    @State private var recallLevel = 0
    @State private var isAnswerRevealed = false

    var body: some View {
        SessionScaffold(
            title: "Recall",
            progressLabel: "Step \(stepIndex + 1) of \(totalCount)",
            progress: Double(stepIndex + 1) / Double(max(totalCount, 1)),
            bottom: {
                HStack(spacing: 16) {
                    Button(isAnswerRevealed ? "Hide answer" : "Show answer") {
                        isAnswerRevealed.toggle()
                    }
                        .buttonStyle(SecondaryButtonStyle())
                    Button(primaryActionTitle, action: advanceRecall)
                        .buttonStyle(PrimaryButtonStyle())
                }
            },
            exitTapped: exitTapped
        ) {
            VStack(alignment: .leading, spacing: 28) {
                if let contextLabel = appModel.studyContextLabel(for: item.unit) {
                    Text(contextLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mutedText)
                }

                Text(item.unit.reference)
                    .font(.headline)
                    .foregroundStyle(Color.accentMoss)

                if appModel.typeRecallEnabled {
                    TypedRecallComposer(
                        promptText: typedPromptText,
                        answerText: displayText,
                        recallLevel: recallLevel,
                        isAnswerRevealed: isAnswerRevealed
                    )
                } else {
                    RecallText(
                        text: displayText,
                        hiddenWordIndexes: hiddenWordIndexes,
                        isAnswerRevealed: isAnswerRevealed
                    )
                    .contentTransition(.opacity)
                }

                Text(appModel.preferredTranslation.shortName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentMoss)

                if appModel.shouldShowESVAttribution(for: item.unit.reference) {
                    ESVAttributionView()
                } else if let translationSupportText = appModel.translationSupportText(for: item.unit.reference) {
                    TranslationSupportView(message: translationSupportText)
                }

                HStack(spacing: 8) {
                    StatusPill(title: "Recall \(recallLevel + 1) of 4")
                    if isAnswerRevealed {
                        StatusPill(title: "Answer shown", tint: .accentGold)
                    }
                    if passageSections.count > 1 {
                        StatusPill(title: passagePlan.sectionLabel, tint: .accentMoss)
                    }
                }

                Text(recallLevelTitle)
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)

                Text(recallGuidance)
                    .font(.body)
                    .foregroundStyle(Color.mutedText)

                if prefersPhraseMasking, passageSections.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Passage flow")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)

                        Text(passagePlan.strategyLine)
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)

                        ForEach(passageSections.prefix(4)) { section in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(Color.accentGold)
                                    .padding(.top, 5)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(section.title) • \(section.reference)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.accentMoss)
                                    if showsSectionTextPreviews {
                                        Text(section.text)
                                            .font(.caption)
                                            .foregroundStyle(Color.mutedText)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onChange(of: item.unit.id) { _, _ in
            resetState()
        }
        .task(id: "\(appModel.preferredTranslation.rawValue)|\(item.unit.reference)") {
            await appModel.prefetchPreferredTranslation(for: item.unit)
        }
        .animation(.snappy(duration: 0.22), value: recallLevel)
        .animation(.easeInOut(duration: 0.18), value: isAnswerRevealed)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var primaryActionTitle: String {
        recallLevel < 3 ? "Make it harder" : "Rate this verse"
    }

    private var typedPromptText: String {
        switch recallLevel {
        case 0:
            return passageSections.count > 1 ? passageSections.map(\.reference).joined(separator: " • ") : openingPrompt
        case 1:
            return openingPrompt
        case 2:
            return "Type it through from memory."
        default:
            return "Full recall."
        }
    }

    private var recallLevelTitle: String {
        if prefersPhraseMasking {
            switch recallLevel {
            case 0:
                return "Start by recalling missing phrases."
            case 1:
                return "Hold the flow of the whole passage."
            case 2:
                return "Now tighten down to the wording."
            default:
                return "Try the full passage from memory."
            }
        } else {
            switch recallLevel {
            case 0:
                return "Start with a few missing words."
            case 1:
                return "Push recall a bit further."
            case 2:
                return "Move toward full verse recall."
            default:
                return "Try the whole line from memory."
            }
        }
    }

    private var recallGuidance: String {
        if prefersPhraseMasking {
            switch recallLevel {
            case 0:
                return "Keep the thought movement intact before focusing on exact wording."
            case 1:
                return "Use the remaining anchor phrases to carry the whole section."
            case 2:
                return "Most of the wording is hidden now. Say it through carefully."
            default:
                return "Use the answer only if you need to reset the whole section."
            }
        } else {
            switch recallLevel {
            case 0:
                return "Recall the missing phrases before you move on."
            case 1:
                return "Fewer visible anchors. Say it through once without tapping ahead."
            case 2:
                return "Only a few small connector words remain visible now."
            default:
                return "Use the full verse display only if you need a reset."
            }
        }
    }

    private var hiddenWordIndexes: Set<Int> {
        RecallMask.hiddenWordIndexes(in: displayText, level: recallLevel, prefersPhraseMasking: prefersPhraseMasking)
    }

    private var displayText: String {
        appModel.displayText(for: item.unit)
    }

    private var openingPrompt: String {
        let words = displayText.split(separator: " ").map(String.init)
        return words.prefix(6).joined(separator: " ")
    }

    private var prefersPhraseMasking: Bool {
        item.unit.kind == .passage || displayText.split(separator: " ").count >= 26
    }

    private var passageSections: [PassageSection] {
        PassageBreakdown.sections(
            for: appModel.verses(for: item.unit),
            translation: appModel.preferredTranslation == .esv ? .kjv : appModel.preferredTranslation
        )
    }

    private var passagePlan: PassagePlanSummary {
        PassageBreakdown.summary(
            for: appModel.verses(for: item.unit),
            translation: appModel.preferredTranslation == .esv ? .kjv : appModel.preferredTranslation
        )
    }

    private var showsSectionTextPreviews: Bool {
        appModel.preferredTranslation != .esv
    }

    private func advanceRecall() {
        if recallLevel < 3 {
            HapticManager.makeItHarder()
            recallLevel += 1
            isAnswerRevealed = false
            return
        }

        HapticManager.recallAdvanced()
        continueTapped()
    }

    private func resetState() {
        recallLevel = 0
        isAnswerRevealed = false
    }
}

private struct TypedRecallComposer: View {
    @State private var typedText = ""
    @FocusState private var isFocused: Bool
    let promptText: String
    let answerText: String
    let recallLevel: Int
    let isAnswerRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(promptLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentGold)

            if !promptText.isEmpty {
                Text(promptText)
                    .font(.subheadline)
                    .foregroundStyle(Color.mutedText)
                    .contentTransition(.opacity)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.borderSand, lineWidth: 1)
                    )

                if typedText.isEmpty {
                    Text("Type from memory here.")
                        .font(.body)
                        .foregroundStyle(Color.mutedText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                }

                TextEditor(text: $typedText)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(Color.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 180)
                    .background(Color.clear)
                    .focused($isFocused)
            }

            HStack(spacing: 8) {
                StatusPill(title: accuracyLine, tint: accuracyTint)
                if typedText.split(separator: " ").count > 0 {
                    StatusPill(title: "\(typedText.split(separator: " ").count) typed", tint: .accentGold)
                }
            }

            if isAnswerRevealed {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Answer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentMoss)

                    Text(answerText)
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .foregroundStyle(Color.primaryText)
                }
                .cardSurface()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear { isFocused = true }
    }

    private var promptLabel: String {
        switch recallLevel {
        case 0: return "Anchor"
        case 1: return "Opening line"
        case 2: return "From memory"
        default: return "Full recall"
        }
    }

    private var accuracyLine: String {
        let score = Int((accuracyScore * 100).rounded())
        return typedText.isEmpty ? "Start typing" : "\(score)% match"
    }

    private var accuracyTint: Color {
        switch accuracyScore {
        case 0.85...: return .accentMoss
        case 0.55...: return .accentGold
        default: return .red.opacity(0.75)
        }
    }

    private var accuracyScore: Double {
        let answerTokens = normalizedTokens(in: answerText)
        let typedTokens = normalizedTokens(in: typedText)
        guard !answerTokens.isEmpty, !typedTokens.isEmpty else { return 0 }
        let matched = zip(answerTokens, typedTokens).filter(==).count
        return Double(matched) / Double(max(answerTokens.count, typedTokens.count))
    }

    private func normalizedTokens(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                token.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            }
            .filter { !$0.isEmpty }
    }
}

struct ESVAttributionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ESV text used by permission.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)
            Link("esv.org", destination: URL(string: "https://www.esv.org")!)
                .font(.caption.weight(.semibold))
        }
    }
}

struct TranslationSupportView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Color.mutedText)
    }
}

struct RatingView: View {
    @State private var animateButtons = false
    let submit: (ReviewRating) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Session check-in")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            VStack(alignment: .center, spacing: 16) {
                Text("How did that feel?")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)

                Text("A simple check-in helps the app bring this verse back at the right time.")
                    .font(.body)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            VStack(spacing: 14) {
                Button("Easy") { HapticManager.ratingSubmitted(); submit(.easy) }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                    .scaleEffect(animateButtons ? 1 : 0.98)
                    .opacity(animateButtons ? 1 : 0)
                    .offset(y: animateButtons ? 0 : 12)
                    .animation(.spring(duration: 0.4, bounce: 0.32), value: animateButtons)
                Button("Medium") { HapticManager.ratingSubmitted(); submit(.medium) }
                    .buttonStyle(FilledSoftButtonStyle())
                    .scaleEffect(animateButtons ? 1 : 0.98)
                    .opacity(animateButtons ? 1 : 0)
                    .offset(y: animateButtons ? 0 : 12)
                    .animation(.spring(duration: 0.4, bounce: 0.32).delay(0.06), value: animateButtons)
                Button("Hard") { HapticManager.ratingSubmitted(); submit(.hard) }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                    .scaleEffect(animateButtons ? 1 : 0.98)
                    .opacity(animateButtons ? 1 : 0)
                    .offset(y: animateButtons ? 0 : 12)
                    .animation(.spring(duration: 0.4, bounce: 0.32).delay(0.12), value: animateButtons)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("No penalties for missing a day.")
                    .font(.headline)
                Text("Your review schedule adjusts naturally when you return.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

            Spacer()
        }
        .padding(24)
        .background(Color.screenBackground.ignoresSafeArea())
        .onAppear { animateButtons = true }
    }
}

struct CompletionView: View {
    @Environment(\.requestReview) private var requestReview
    @State private var didAppear = false
    @State private var pulse = false
    let reviewedCount: Int
    let newVerseCount: Int
    let streak: Int
    let milestones: [String]
    var planContext: SessionDraftPlanContext?
    var planDuration: Int?
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Circle()
                    .fill(Color.accentMoss.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .overlay {
                        Text("Amen")
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.accentMoss)
                    }
                    .shadow(color: Color.accentMoss.opacity(pulse ? 0.25 : 0.08), radius: pulse ? 20 : 10)
                    .scaleEffect(didAppear ? (reviewedCount + newVerseCount > 0 ? 1.02 : 1.0) : 0.94)
                    .animation(.spring(duration: 0.55, bounce: 0.35), value: didAppear)

                Text("You’re done for today.")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .offset(y: didAppear ? 0 : 8)
                    .opacity(didAppear ? 1 : 0)
                    .animation(.easeOut(duration: 0.32).delay(0.04), value: didAppear)

                Text(summaryText)
                    .font(.body)
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)
                    .opacity(didAppear ? 1 : 0)
                    .animation(.easeOut(duration: 0.32).delay(0.08), value: didAppear)

                if streak > 1 {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.accentGold)
                        Text("\(streak)-day streak")
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)
                    }
                    .opacity(didAppear ? 1 : 0)
                    .animation(.easeOut(duration: 0.32).delay(0.1), value: didAppear)
                }

                if !milestones.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color.accentGold)
                                    .font(.caption)
                                Text(milestone)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primaryText)
                            }
                            .opacity(didAppear ? 1 : 0)
                            .animation(.easeOut(duration: 0.32).delay(0.12 + Double(index) * 0.06), value: didAppear)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .cardSurface()
                }

                if let ctx = planContext, let duration = planDuration {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundStyle(Color.accentMoss)
                            Text(ctx.dayNumber >= duration
                                 ? "\(ctx.planTitle) complete!"
                                 : "Day \(ctx.dayNumber) of \(duration)")
                                .font(.headline)
                                .foregroundStyle(Color.primaryText)
                        }

                        ProgressView(value: Double(ctx.dayNumber), total: Double(duration))
                            .tint(Color.accentMoss)

                        Text(ctx.dayTitle)
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)

                        if ctx.dayNumber < duration {
                            Text("Tomorrow: day \(ctx.dayNumber + 1)")
                                .font(.caption)
                                .foregroundStyle(Color.accentGold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .cardSurface()
                    .opacity(didAppear ? 1 : 0)
                    .animation(.easeOut(duration: 0.32).delay(0.14), value: didAppear)
                }

                Text("No penalties for missing a day. Your review schedule adjusts naturally when you return.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .cardSurface()

                Button("Done", action: done)
                    .buttonStyle(PrimaryButtonStyle())
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 10)
                    .animation(.easeOut(duration: 0.34).delay(0.16), value: didAppear)

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .transition(.opacity)
        .onAppear {
            didAppear = true
            HapticManager.sessionCompleted()
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            // Request App Store review at high-emotion milestones
            let isPlanComplete = planContext.map { ctx in planDuration.map { ctx.dayNumber >= $0 } ?? false } ?? false
            let hasStreakMilestone = [7, 14, 30].contains(streak)
            let hasReviewMilestone = milestones.contains(where: { $0.contains("25 total") || $0.contains("50 total") || $0.contains("100 total") })
            if isPlanComplete || hasStreakMilestone || hasReviewMilestone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    requestReview()
                }
            }
        }
    }

    private var summaryText: String {
        let reviewed = "\(reviewedCount) verse" + (reviewedCount == 1 ? "" : "s") + " reviewed"
        let introduced = "\(newVerseCount) new verse" + (newVerseCount == 1 ? "" : "s") + " introduced"
        return reviewedCount == 0 && newVerseCount == 0 ? "You’re fully caught up for now." : "\(reviewed)\n\(introduced)"
    }
}

private struct SessionScaffold<Content: View, Bottom: View>: View {
    let title: String
    let progressLabel: String
    let progress: Double
    @ViewBuilder let bottom: Bottom
    let exitTapped: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save and close", action: exitTapped)
                    .font(.subheadline.weight(.medium))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(progressLabel)
                    .font(.headline)
                ProgressView(value: progress)
                    .tint(Color.accentMoss)
                Text("Your place is saved if you leave.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            content

            Spacer()

            bottom
        }
        .padding(24)
        .background(Color.screenBackground.ignoresSafeArea())
    }
}

private struct RecallText: View {
    let text: String
    let hiddenWordIndexes: Set<Int>
    let isAnswerRevealed: Bool

    var body: some View {
        let words = text.split(separator: " ").map(String.init)

        RecallFlowLayout(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                RecallWord(
                    word: word,
                    isHidden: hiddenWordIndexes.contains(index) && !RecallMask.normalized(word).isEmpty,
                    isAnswerRevealed: isAnswerRevealed,
                    staggerDelay: Double(index) * 0.03
                )
            }
        }
    }
}

private struct RecallWord: View {
    let word: String
    let isHidden: Bool
    let isAnswerRevealed: Bool
    let staggerDelay: Double

    var body: some View {
        let displayText = isHidden && !isAnswerRevealed ? RecallMask.placeholder(for: word) : word

        Text(displayText)
            .font(.system(size: 30, weight: .medium, design: .serif))
            .foregroundStyle(isHidden ? (isAnswerRevealed ? Color.primaryText : Color.mutedText) : Color.primaryText)
            .underline(isHidden && !isAnswerRevealed)
            .opacity(isHidden && !isAnswerRevealed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15).delay(staggerDelay), value: isHidden)
            .animation(.easeInOut(duration: 0.18), value: isAnswerRevealed)
    }
}

private struct RecallFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        guard !rows.isEmpty else { return .zero }
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + CGFloat(rows.count - 1) * 4
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        var subviewIndex = 0
        for row in rows {
            var x = bounds.minX
            for _ in 0..<row.count {
                let size = subviews[subviewIndex].sizeThatFits(.unspecified)
                subviews[subviewIndex].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
                subviewIndex += 1
            }
            y += row.height + 4
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [(count: Int, height: CGFloat)] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [(count: Int, height: CGFloat)] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var currentCount = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = currentCount == 0 ? size.width : size.width + spacing
            if currentWidth + needed > maxWidth, currentCount > 0 {
                rows.append((count: currentCount, height: currentHeight))
                currentWidth = size.width
                currentHeight = size.height
                currentCount = 1
            } else {
                currentWidth += needed
                currentHeight = max(currentHeight, size.height)
                currentCount += 1
            }
        }
        if currentCount > 0 {
            rows.append((count: currentCount, height: currentHeight))
        }
        return rows
    }
}

private enum RecallMask {
    static func hiddenWordIndexes(in text: String, level: Int, prefersPhraseMasking: Bool) -> Set<Int> {
        let words = text.split(separator: " ").map(String.init)
        let eligibleIndexes = words.enumerated().compactMap { index, word -> Int? in
            let cleaned = normalized(word)
            return cleaned.count >= 3 ? index : nil
        }

        guard !eligibleIndexes.isEmpty else { return [] }

        if prefersPhraseMasking {
            let phraseGroups = phraseEligibleIndexes(in: words)
            if !phraseGroups.isEmpty {
                switch level {
                case 0:
                    return Set(phraseGroups.enumerated().flatMap { offset, group in
                        offset.isMultiple(of: 2) ? [] : group
                    })
                case 1:
                    return Set(phraseGroups.enumerated().flatMap { offset, group in
                        offset.isMultiple(of: 3) ? [] : group
                    })
                case 2:
                    return Set(eligibleIndexes.enumerated().compactMap { offset, index in
                        offset % 4 != 3 ? index : nil
                    })
                default:
                    return Set(eligibleIndexes)
                }
            }
        }

        switch level {
        case 0:
            return Set(eligibleIndexes.enumerated().compactMap { offset, index in
                offset.isMultiple(of: 4) ? index : nil
            })
        case 1:
            return Set(eligibleIndexes.enumerated().compactMap { offset, index in
                offset.isMultiple(of: 2) ? index : nil
            })
        case 2:
            return Set(eligibleIndexes.enumerated().compactMap { offset, index in
                offset % 4 != 3 ? index : nil
            })
        default:
            return Set(eligibleIndexes)
        }
    }

    static func normalized(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
    }

    static func placeholder(for word: String) -> String {
        let cleaned = normalized(word)
        let width = max(cleaned.count, 4)
        return String(repeating: "_", count: width)
    }

    private static func phraseEligibleIndexes(in words: [String]) -> [[Int]] {
        var groups: [[Int]] = []
        var current: [Int] = []

        for (index, word) in words.enumerated() {
            let cleaned = normalized(word)
            if cleaned.count >= 3 {
                current.append(index)
            }

            if word.last.map({ ",;:.!?".contains($0) }) == true {
                if !current.isEmpty {
                    groups.append(current)
                    current = []
                }
            }
        }

        if !current.isEmpty {
            groups.append(current)
        }

        return groups.filter { !$0.isEmpty }
    }
}

