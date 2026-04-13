import SwiftUI
import ScriptureMemory

struct JourneyView: View {
    @Environment(AppModel.self) private var appModel
    @State private var didAppear = false
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summaryRow

                if !appModel.recentReviewEvents.isEmpty {
                    rhythmSection
                }

                if isEffectivelyEmpty {
                    emptyState
                }

                if !appModel.recentReviewEvents.isEmpty {
                    recentActivitySection
                }

                if !filteredStrongestUnits.isEmpty {
                    strongestSection
                }

                if !filteredOlderUnits.isEmpty {
                    olderMaterialSection
                }

                if appModel.selectedCollectionID == BuiltInContent.myVersesSetID, !appModel.practiceOnlyCustomStudyUnits.isEmpty {
                    practiceShelfSection
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .searchable(text: $searchText, prompt: "Search verses")
        .onAppear { didAppear = true }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "text.book.closed",
            headline: "Your journey will fill in as you review",
            bodyText: "Once you begin reviewing, this screen will help you revisit older material, see what is sticking, and notice what has gone quiet."
        )
    }

    private var header: some View {
        Text("See what has stayed with you, what you have touched recently, and what may need a gentle return.")
            .font(.subheadline)
            .foregroundStyle(Color.mutedText)
            .offset(y: didAppear ? 0 : 10)
            .opacity(didAppear ? 1 : 0)
            .animation(.easeOut(duration: 0.35), value: didAppear)
    }

    private var summaryRow: some View {
        HStack(spacing: 16) {
            summaryCard(title: "Started", value: "\(appModel.startedVerseCount)", detail: "Units you have begun")
            summaryCard(title: "This week", value: "\(appModel.reviewedThisWeekCount)", detail: "Review passes recorded")
            summaryCard(title: "Due", value: "\(appModel.dueReviewCount)", detail: "Ready in the queue")
        }
        .offset(y: didAppear ? 0 : 14)
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.36).delay(0.03), value: didAppear)
    }

    private func summaryCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primaryText)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var rhythmSection: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days: [Date] = (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: -(29 - offset), to: today)
        }
        let activeDates = Set(appModel.recentReviewEvents.map { calendar.startOfDay(for: $0.reviewedAt) })
        let activeCount = days.filter { activeDates.contains($0) }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("Your rhythm")
                .font(.headline)

            Text("The last 30 days")
                .font(.caption)
                .foregroundStyle(Color.mutedText)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 10), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    Circle()
                        .fill(activeDates.contains(day) ? Color.accentMoss : Color.borderSand)
                        .frame(width: 14, height: 14)
                }
            }

            Text("\(activeCount) of 30 days active")
                .font(.caption)
                .foregroundStyle(Color.mutedText)
        }
        .cardSurface()
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.headline)

            ForEach(Array(appModel.recentReviewEvents.prefix(6)), id: \.id) { event in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(event.unitReference)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        Text(relativeDateString(for: event.reviewedAt))
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                    }

                    HStack(spacing: 8) {
                        StatusPill(title: event.kind == .restudy ? "Restudy" : "Review", tint: .accentGold)
                        StatusPill(title: event.rating.rawValue.capitalized, tint: color(for: event.rating))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            }
        }
    }

    private var strongestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Held longest")
                .font(.headline)

            ForEach(Array(filteredStrongestUnits.prefix(5)), id: \.id) { unit in
                JourneyUnitCard(unit: unit)
            }
        }
    }

    private var olderMaterialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gentle return")
                .font(.headline)

            Text("These are started units you have not seen in a bit. They may be worth touching again soon.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)

            ForEach(Array(filteredOlderUnits.prefix(5)), id: \.id) { unit in
                JourneyUnitCard(unit: unit)
            }
        }
    }

    private var practiceShelfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Practice shelf")
                .font(.headline)

            Text("These units are kept close without affecting the daily queue.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)

            ForEach(appModel.practiceOnlyCustomStudyUnits, id: \.id) { unit in
                JourneyUnitCard(unit: unit)
            }
        }
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

    private func matchesSearch(_ unit: StudyUnit) -> Bool {
        guard !searchText.isEmpty else { return true }
        return unit.reference.localizedCaseInsensitiveContains(searchText)
            || appModel.displayText(for: unit).localizedCaseInsensitiveContains(searchText)
    }

    private var filteredStrongestUnits: [StudyUnit] {
        appModel.strongestStudyUnits.filter(matchesSearch)
    }

    private var filteredOlderUnits: [StudyUnit] {
        appModel.olderStartedUnits.filter(matchesSearch)
    }

    private var isEffectivelyEmpty: Bool {
        appModel.recentReviewEvents.isEmpty &&
        appModel.strongestStudyUnits.isEmpty &&
        appModel.olderStartedUnits.isEmpty &&
        appModel.practiceOnlyCustomStudyUnits.isEmpty
    }
}

private struct JourneyUnitCard: View {
    @Environment(AppModel.self) private var appModel
    let unit: StudyUnit

    var body: some View {
        NavigationLink {
            StudyUnitDetailView(unit: unit)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let contextLabel = appModel.studyContextLabel(for: unit) {
                            Text(contextLabel)
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                        }
                        Text(unit.reference)
                            .font(.headline)
                            .foregroundStyle(Color.primaryText)
                        Text(statusLine)
                            .font(.caption)
                            .foregroundStyle(Color.accentMoss)
                    }

                    Spacer()

                    if let progress {
                        Text(intervalLine(for: progress))
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                    }
                }

                Text(appModel.displayText(for: unit))
                    .font(.subheadline)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let progress {
                        MasteryBadge(tier: progress.masteryTier)
                        StatusPill(title: "\(progress.reviewCount) review\(progress.reviewCount == 1 ? "" : "s")", tint: .accentGold)
                    }

                    if unit.track == .practiceOnly {
                        StatusPill(title: "Practice only")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(ScalableCardButtonStyle())
        .contextMenu {
            Button {
                appModel.startFocusedPractice(for: unit)
            } label: {
                Label("Practice now", systemImage: "arrow.trianglehead.2.counterclockwise")
            }

            NavigationLink {
                StudyUnitDetailView(unit: unit)
            } label: {
                Label("View progress", systemImage: "chart.bar")
            }
        }
    }

    private var progress: VerseProgress? {
        appModel.progress(for: unit)
    }

    private var statusLine: String {
        guard let progress else { return "Not started yet" }
        if let nextReviewAt = progress.nextReviewAt, nextReviewAt <= .now {
            return "Ready for review"
        }
        if let lastReviewedAt = progress.lastReviewedAt {
            return "Last reviewed \(formatted(lastReviewedAt))"
        }
        return "Started"
    }

    private func intervalLine(for progress: VerseProgress) -> String {
        progress.intervalDays <= 1 ? "Daily" : "\(progress.intervalDays)-day rhythm"
    }

    private func formatted(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct StudyUnitDetailView: View {
    @Environment(AppModel.self) private var appModel
    let unit: StudyUnit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    if let contextLabel = appModel.studyContextLabel(for: unit) {
                        Text(contextLabel)
                            .font(.subheadline)
                            .foregroundStyle(Color.mutedText)
                    }

                    Text(unit.reference)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Color.primaryText)

                    HStack(spacing: 8) {
                        if let progress = appModel.progress(for: unit) {
                            MasteryBadge(tier: progress.masteryTier)
                        }
                        StatusPill(title: appModel.preferredTranslation.shortName)
                        StatusPill(title: unit.kind == .singleVerse ? "Single verse" : "Passage", tint: .accentGold)
                        StatusPill(title: unit.track.title, tint: .accentMoss)
                    }
                }

                Text(appModel.displayText(for: unit))
                    .font(.system(.title2, design: .serif, weight: .medium))
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.primaryText)

                if appModel.shouldShowESVAttribution(for: unit.reference) {
                    ESVAttributionView()
                } else if let translationSupportText = appModel.translationSupportText(for: unit.reference) {
                    TranslationSupportView(message: translationSupportText)
                }

                if let shareImage = renderVerseImage(
                    reference: unit.reference,
                    text: appModel.displayText(for: unit),
                    translation: appModel.preferredTranslation.displayName
                ) {
                    ShareLink(
                        item: Image(uiImage: shareImage),
                        preview: SharePreview(unit.reference, image: Image(uiImage: shareImage))
                    ) {
                        Label("Share verse card", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                }

                if let progress = appModel.progress(for: unit) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Progress")
                            .font(.headline)

                        DetailLine(title: "Reviews", value: "\(progress.reviewCount)")
                        DetailLine(title: "Last rating", value: progress.lastRating?.rawValue.capitalized ?? "None yet")
                        DetailLine(title: "Last reviewed", value: formattedDate(progress.lastReviewedAt) ?? "Not yet")
                        DetailLine(title: "Next review", value: formattedDate(progress.nextReviewAt) ?? "Not scheduled")
                        DetailLine(title: "Current rhythm", value: progress.intervalDays <= 1 ? "Daily" : "\(progress.intervalDays) days")
                    }
                    .cardSurface()
                }

                if !appModel.reviewEvents(for: unit.id).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent passes")
                            .font(.headline)

                        ForEach(Array(appModel.reviewEvents(for: unit.id).prefix(5)), id: \.id) { event in
                            HStack {
                                Text(formattedDate(event.reviewedAt) ?? "Recent")
                                    .font(.caption)
                                    .foregroundStyle(Color.mutedText)
                                Spacer()
                                StatusPill(title: event.rating.rawValue.capitalized, tint: color(for: event.rating))
                            }
                        }
                    }
                    .cardSurface()
                }

                if unit.collectionID == BuiltInContent.myVersesSetID {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Placement")
                            .font(.headline)

                        if !bundleUnits.isEmpty {
                            Button("Practice full section plan") {
                                appModel.startFocusedPractice(for: bundleUnits, focusReference: unit.title)
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            if let shareURL = appModel.shareURLForSectionBundle(title: unit.title) {
                                ShareLink(item: shareURL, message: Text("Memorize \(unit.title) with me in Hide the Word")) {
                                    Label("Share this plan", systemImage: "person.2")
                                }
                                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                            }
                        }

                        if unit.track == .scheduled {
                            Button("Move to practice only") {
                                appModel.moveCustomStudyUnit(unit.id, to: .practiceOnly)
                            }
                            .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                        } else {
                            Button("Move to daily queue") {
                                appModel.moveCustomStudyUnit(unit.id, to: .scheduled)
                            }
                            .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                        }

                        if bundleUnits.isEmpty {
                            Button("Practice this now") {
                                appModel.startFocusedPractice(for: unit)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        } else {
                            Button("Practice this now") {
                                appModel.startFocusedPractice(for: unit)
                            }
                            .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                        }
                    }
                    .cardSurface()
                } else {
                    Button("Practice this now") {
                        appModel.startFocusedPractice(for: unit)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .task(id: "\(appModel.preferredTranslation.rawValue)|\(unit.reference)") {
            await appModel.prefetchPreferredTranslation(for: unit)
        }
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

    private var bundleUnits: [StudyUnit] {
        appModel.sectionBundleUnits(for: unit)
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.mutedText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.primaryText)
        }
    }
}

#Preview("Journey · XXXL") {
    JourneyView()
        .environment(AppModel(progressStore: try! ReviewProgressStore(inMemory: true)))
        .dynamicTypeSize(.xxxLarge)
}

#Preview("Journey · AX Medium") {
    JourneyView()
        .environment(AppModel(progressStore: try! ReviewProgressStore(inMemory: true)))
        .dynamicTypeSize(.accessibility2)
}

#Preview("Journey · AX XL") {
    JourneyView()
        .environment(AppModel(progressStore: try! ReviewProgressStore(inMemory: true)))
        .dynamicTypeSize(.accessibility3)
}
