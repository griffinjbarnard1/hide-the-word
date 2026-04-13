import ScriptureMemory
import SwiftUI

struct VerseLibraryView: View {
    private struct AddFeedback: Equatable {
        let title: String
        let message: String
        let focusUnitIDs: [UUID]
        let focusReference: String?
    }

    private struct BundleDisplay: Identifiable {
        let summary: SectionBundleSummary
        let units: [StudyUnit]

        var id: String { summary.id }
    }

    private enum SaveMode: String, CaseIterable, Identifiable {
        case singleVerses
        case passage
        case sectionBundle

        var id: String { rawValue }

        var title: String {
            switch self {
            case .singleVerses:
                return "Separate verses"
            case .passage:
                return "One passage"
            case .sectionBundle:
                return "Section bundle"
            }
        }

        var summary: String {
            switch self {
            case .singleVerses:
                return "Each verse gets its own review schedule."
            case .passage:
                return "The whole range is memorized as one unit."
            case .sectionBundle:
                return "Break the range into connected sections that can be learned one by one."
            }
        }
    }

    private enum TrackMode: String, CaseIterable, Identifiable {
        case scheduled
        case practiceOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .scheduled:
                return "Daily queue"
            case .practiceOnly:
                return "Practice only"
            }
        }

        var summary: String {
            switch self {
            case .scheduled:
                return "This material can appear in your normal review sessions."
            case .practiceOnly:
                return "Keep it available for focused practice without adding it to the daily queue."
            }
        }

        var studyTrack: StudyUnitTrack {
            switch self {
            case .scheduled:
                return .scheduled
            case .practiceOnly:
                return .practiceOnly
            }
        }
    }

    @Environment(AppModel.self) private var appModel

    @State private var selectedBookID = BibleCatalog.books.first?.id ?? "genesis"
    @State private var startChapter = 1
    @State private var startVerse = 1
    @State private var endChapter = 1
    @State private var endVerse = 1
    @State private var saveMode: SaveMode = .singleVerses
    @State private var trackMode: TrackMode = .scheduled
    @State private var addFeedback: AddFeedback?
    @State private var didAppear = false
    @State private var searchText = ""
    @State private var expandedBundleTitles: Set<String> = []

    var body: some View {
        List {
            headerSection

            if !filteredScheduledBundles.isEmpty || !filteredScheduledLooseUnits.isEmpty {
                customUnitsSection(
                    title: "Scheduled Units",
                    bundles: filteredScheduledBundles,
                    looseUnits: filteredScheduledLooseUnits
                )
            }

            if !filteredPracticeBundles.isEmpty || !filteredPracticeLooseUnits.isEmpty {
                customUnitsSection(
                    title: "Practice Only",
                    bundles: filteredPracticeBundles,
                    looseUnits: filteredPracticeLooseUnits
                )
            }

            pickerSection
            previewSection
            actionsSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.screenBackground.ignoresSafeArea())
        .animation(.snappy(duration: 0.28), value: selectedRangeReference)
        .animation(.snappy(duration: 0.28), value: appModel.customStudyUnits.count)
        .searchable(text: $searchText, prompt: "Search by reference")
        .onAppear { didAppear = true }
        .onChange(of: selectedBookID, initial: true) { _, _ in
            resetSelectionForBook()
        }
        .onChange(of: startChapter, initial: false) { _, _ in
            normalizeSelection()
        }
        .onChange(of: startVerse, initial: false) { _, _ in
            normalizeSelection()
        }
        .onChange(of: endChapter, initial: false) { _, _ in
            normalizeSelection()
        }
        .onChange(of: endVerse, initial: false) { _, _ in
            normalizeSelection()
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bible Library")
                    .font(.title.weight(.semibold))
                Text("Pick a reference range, decide how it should be studied, and add it into `My Verses` without breaking your flow.")
                    .font(.subheadline)
                    .foregroundStyle(Color.mutedText)

                HStack(spacing: 8) {
                    StatusPill(title: "\(appModel.scheduledCustomStudyUnits.count) scheduled", tint: .accentGold)
                    StatusPill(title: "\(appModel.practiceOnlyCustomStudyUnits.count) practice-only")
                }

                Text("Long passages are automatically broken into manageable sections before they ask for full recall.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }
            .offset(y: didAppear ? 0 : 10)
            .opacity(didAppear ? 1 : 0)
            .animation(.easeOut(duration: 0.34), value: didAppear)
            .listRowBackground(Color.screenBackground)
            .listRowSeparator(.hidden)
        }
    }

    private func matchesSearch(_ text: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(searchText)
    }

    private func bundleDisplays(for track: StudyUnitTrack) -> [BundleDisplay] {
        appModel.customSectionBundleSummaries
            .filter { summary in
                switch track {
                case .scheduled:
                    return summary.scheduledCount > 0 && summary.practiceOnlyCount == 0
                case .practiceOnly:
                    return summary.practiceOnlyCount > 0 && summary.scheduledCount == 0
                }
            }
            .map { summary in
                BundleDisplay(summary: summary, units: appModel.sectionBundleUnits(forTitle: summary.title))
            }
            .filter { bundle in
                matchesSearch(bundle.summary.title)
                    || matchesSearch(bundle.summary.firstReference)
                    || matchesSearch(bundle.summary.lastReference)
                    || bundle.units.contains(where: { unit in
                        matchesSearch(unit.reference) || matchesSearch(appModel.displayText(for: unit))
                    })
            }
    }

    private func looseUnits(for track: StudyUnitTrack) -> [StudyUnit] {
        let source: [StudyUnit] = {
            switch track {
            case .scheduled:
                return appModel.scheduledCustomStudyUnits
            case .practiceOnly:
                return appModel.practiceOnlyCustomStudyUnits
            }
        }()

        return source.filter { unit in
            unit.title == unit.reference &&
            (
                matchesSearch(unit.reference) ||
                matchesSearch(appModel.displayText(for: unit))
            )
        }
    }

    private var filteredScheduledBundles: [BundleDisplay] {
        bundleDisplays(for: .scheduled)
    }

    private var filteredPracticeBundles: [BundleDisplay] {
        bundleDisplays(for: .practiceOnly)
    }

    private var filteredScheduledLooseUnits: [StudyUnit] {
        looseUnits(for: .scheduled)
    }

    private var filteredPracticeLooseUnits: [StudyUnit] {
        looseUnits(for: .practiceOnly)
    }

    private func customUnitsSection(title: String, bundles: [BundleDisplay], looseUnits: [StudyUnit]) -> some View {
        Section(title) {
            ForEach(bundles) { bundle in
                sectionBundleRow(bundle)
                    .listRowBackground(Color.paper)
            }

            ForEach(looseUnits, id: \.id) { unit in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let contextLabel = appModel.studyContextLabel(for: unit) {
                            Text(contextLabel)
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                        }
                        Text(unit.reference)
                            .font(.headline)
                        HStack(spacing: 6) {
                            Text(unit.kind == .singleVerse ? "Single verse" : "Passage")
                                .font(.caption)
                                .foregroundStyle(Color.accentMoss)
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                            Text(unit.track.title)
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                        }
                        Text(appModel.displayText(for: unit))
                            .font(.subheadline)
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(2)
                    }

                    Spacer()

                    Menu {
                        if !appModel.sectionBundleUnits(for: unit).isEmpty {
                            Button("Practice full section plan") {
                                appModel.startFocusedPractice(for: appModel.sectionBundleUnits(for: unit), focusReference: unit.title)
                            }
                        }

                        Button("Practice this now") {
                            appModel.startFocusedPractice(for: unit)
                        }

                        if unit.track == .scheduled {
                            Button("Move to practice only") {
                                appModel.moveCustomStudyUnit(unit.id, to: .practiceOnly)
                            }
                        } else {
                            Button("Move to daily queue") {
                                appModel.moveCustomStudyUnit(unit.id, to: .scheduled)
                            }
                        }

                        Button("Remove", role: .destructive) {
                            appModel.removeCustomStudyUnit(unit.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(Color.mutedText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.paper)
            }
        }
    }

    private func sectionBundleRow(_ bundle: BundleDisplay) -> some View {
        let isExpanded = expandedBundleTitles.contains(bundle.summary.title)

        return DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { expanded in
                    if expanded {
                        expandedBundleTitles.insert(bundle.summary.title)
                    } else {
                        expandedBundleTitles.remove(bundle.summary.title)
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(bundle.units, id: \.id) { unit in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(unit.reference)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primaryText)
                            Text(appModel.displayText(for: unit))
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                                .lineLimit(2)
                        }

                        Spacer()

                        Button("Practice") {
                            appModel.startFocusedPractice(for: unit)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(bundle.summary.title)
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)

                    Text("\(bundle.summary.firstReference) to \(bundle.summary.lastReference)")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)

                    HStack(spacing: 6) {
                        Text("\(bundle.summary.sectionCount) section\(bundle.summary.sectionCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Color.accentMoss)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                        Text(bundle.summary.practiceOnlyCount > 0 ? "Practice only" : "Daily queue")
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                    }
                }

                Spacer()

                Menu {
                    Button("Practice full section plan") {
                        appModel.startFocusedPractice(for: bundle.units, focusReference: bundle.summary.title)
                    }

                    if bundle.summary.practiceOnlyCount > 0 {
                        Button("Move full plan to daily queue") {
                            appModel.moveSectionBundle(bundle.summary.title, to: .scheduled)
                        }
                    } else {
                        Button("Move full plan to practice only") {
                            appModel.moveSectionBundle(bundle.summary.title, to: .practiceOnly)
                        }
                    }

                    Button("Remove full plan", role: .destructive) {
                        appModel.removeSectionBundle(bundle.summary.title)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(Color.mutedText)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .tint(Color.primaryText)
    }

    private var pickerSection: some View {
        Section("Build a Range") {
            Picker("Book", selection: $selectedBookID) {
                ForEach(BibleCatalog.books, id: \.id) { book in
                    Text(book.name).tag(book.id)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Start")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentMoss)

                HStack(spacing: 12) {
                    Picker("Chapter", selection: $startChapter) {
                        ForEach(chapterOptions, id: \.self) { chapter in
                            Text("Chapter \(chapter)").tag(chapter)
                        }
                    }

                    Picker("Verse", selection: $startVerse) {
                        ForEach(startVerseOptions, id: \.self) { verse in
                            Text("Verse \(verse)").tag(verse)
                        }
                    }
                }
                .pickerStyle(.menu)
            }
            .listRowBackground(Color.paper)

            VStack(alignment: .leading, spacing: 12) {
                Text("End")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentGold)

                HStack(spacing: 12) {
                    Picker("Chapter", selection: $endChapter) {
                        ForEach(chapterOptions.filter { $0 >= startChapter }, id: \.self) { chapter in
                            Text("Chapter \(chapter)").tag(chapter)
                        }
                    }

                    Picker("Verse", selection: $endVerse) {
                        ForEach(endVerseOptions, id: \.self) { verse in
                            Text("Verse \(verse)").tag(verse)
                        }
                    }
                }
                .pickerStyle(.menu)
            }
            .listRowBackground(Color.paper)

            HStack(spacing: 12) {
                Button("Single verse") {
                    endChapter = startChapter
                    endVerse = startVerse
                    saveMode = .singleVerses
                    normalizeSelection()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Whole chapter") {
                    startVerse = 1
                    endChapter = startChapter
                    endVerse = BibleCatalog.lastVerseNumber(in: selectedBookID, chapter: startChapter)
                    saveMode = .sectionBundle
                    normalizeSelection()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .listRowBackground(Color.screenBackground)
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedRangeReference)
                    .font(.headline)
                    .contentTransition(.opacity)

                Text("\(selectedRangeVerses.count) verse\(selectedRangeVerses.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentMoss)

                HStack(spacing: 8) {
                    StatusPill(title: appModel.preferredTranslation.shortName)
                    if selectedRangeVerses.count > 1 {
                        StatusPill(title: passagePlan.lengthLabel, tint: .accentMoss)
                        StatusPill(title: passagePlan.sectionLabel, tint: .accentGold)
                    }
                    if !isSingleVerseSelection {
                        StatusPill(title: saveMode.title, tint: .accentGold)
                    }
                    StatusPill(title: trackMode.title, tint: .accentMoss)
                }

                Text(selectedPreviewText)
                    .font(.subheadline)
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(6)
                    .contentTransition(.opacity)

                if isSingleVerseSelection, !contextVerses.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("In context")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)

                        Text(contextPreviewText)
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                            .lineLimit(6)
                    }
                }

                if appModel.shouldShowESVAttribution(for: selectedRangeReference) {
                    ESVAttributionView()
                } else if let translationSupportText = appModel.translationSupportText(for: selectedRangeReference) {
                    TranslationSupportView(message: translationSupportText)
                }

                if selectedRangeVerses.count > 1 {
                    Text("\(saveMode.summary) \(trackMode.summary)")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)

                    if saveMode == .passage || saveMode == .sectionBundle {
                        Text(passagePlan.strategyLine)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.primaryText)
                    }
                }

                if passageSections.count > 1 {
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Break it down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primaryText)

                        ForEach(passageSections) { section in
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
            }
            .listRowBackground(Color.paper)
            .task(id: "\(appModel.preferredTranslation.rawValue)|\(selectedRangeReference)") {
                await appModel.prefetchPreferredTranslation(
                    reference: selectedRangeReference,
                    estimatedVerseCount: selectedRangeVerses.count
                )
            }
        }
    }

    private var actionsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if let addFeedback {
                    addFeedbackCard(addFeedback)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if isSingleVerseSelection, let verse = selectedRangeVerses.first {
                    Picker("Use this verse in", selection: $trackMode) {
                        ForEach(TrackMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(trackMode.summary)
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)

                    Button(appModel.containsSingleVerseUnit(verse.id) ? "Remove verse from My Verses" : "Add verse to My Verses") {
                        if appModel.containsSingleVerseUnit(verse.id) {
                            appModel.toggleSingleVerseUnit(for: verse)
                            addFeedback = nil
                        } else {
                            let addedUnits = appModel.addSingleVerseUnits(for: [verse], track: trackMode.studyTrack)
                            if let unit = addedUnits.first {
                                setAddFeedback(
                                    title: "Added to My Verses",
                                    message: trackMode == .scheduled ? "This verse is ready in your daily queue." : "This verse is saved for focused practice outside the daily queue.",
                                    focusUnitIDs: [unit.id],
                                    focusReference: unit.reference
                                )
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Picker("Study this range as", selection: $saveMode) {
                        ForEach(SaveMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Use this range in", selection: $trackMode) {
                        ForEach(TrackMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("\(saveMode.summary) \(trackMode.summary)")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)

                    if saveMode == .passage || saveMode == .sectionBundle {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                StatusPill(title: passagePlan.sectionLabel, tint: .accentGold)
                                StatusPill(title: "\(passagePlan.wordCount) words", tint: .accentMoss)
                            }

                            Text(saveMode == .sectionBundle ? sectionBundleStrategyLine : passagePlan.strategyLine)
                                .font(.caption)
                                .foregroundStyle(Color.mutedText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }

                    Button(primaryActionTitle) {
                        performPrimaryAction()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(primaryActionDisabled)
                }
            }
            .listRowBackground(Color.screenBackground)
            .listRowSeparator(.hidden)
        }
    }

    private var chapterOptions: [Int] {
        BibleCatalog.chapterNumbers(in: selectedBookID)
    }

    private var startVerseOptions: [Int] {
        Array(1...BibleCatalog.lastVerseNumber(in: selectedBookID, chapter: startChapter))
    }

    private var endVerseOptions: [Int] {
        let lastVerse = BibleCatalog.lastVerseNumber(in: selectedBookID, chapter: endChapter)
        let lowerBound = endChapter == startChapter ? startVerse : 1
        return Array(lowerBound...lastVerse)
    }

    private var selectedRangeVerses: [ScriptureVerse] {
        BibleCatalog.verseRange(
            bookID: selectedBookID,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse,
            setID: BuiltInContent.myVersesSetID
        )
    }

    private var selectedRangeReference: String {
        guard
            let bookName = BibleCatalog.bookName(for: selectedBookID),
            let first = selectedRangeVerses.first,
            let last = selectedRangeVerses.last
        else {
            return "Pick a verse range"
        }

        if first.id == last.id {
            return first.reference
        }

        if first.chapter == last.chapter {
            return "\(bookName) \(first.chapter):\(first.verse)-\(last.verse)"
        }

        return "\(bookName) \(first.chapter):\(first.verse)-\(last.chapter):\(last.verse)"
    }

    private var selectedPreviewText: String {
        let verses = selectedRangeVerses
        guard !verses.isEmpty else { return "No verses available for this range." }

        if appModel.preferredTranslation == .esv {
            let text = appModel.displayText(forReference: selectedRangeReference, verses: verses)
            return verses.count > 2 ? "\(text.prefix(220))…" : text
        }

        if verses.count == 1 {
            return appModel.displayText(for: verses[0])
        }

        let preview = verses.prefix(2)
            .map { verse in
                "\(verse.chapter):\(verse.verse) \(appModel.displayText(for: verse))"
            }
            .joined(separator: " ")

        return verses.count > 2 ? "\(preview) …" : preview
    }

    private var contextVerses: [ScriptureVerse] {
        guard let verse = selectedRangeVerses.first, isSingleVerseSelection else { return [] }
        let surrounding = BibleCatalog.surroundingVerses(
            bookID: verse.bookID,
            chapter: verse.chapter,
            verseNumber: verse.verse,
            range: 1,
            setID: BuiltInContent.myVersesSetID
        )
        return surrounding.before + [verse] + surrounding.after
    }

    private var contextPreviewText: String {
        contextVerses.map { verse in
            let prefix = verse.reference == selectedRangeReference ? "[\(verse.chapter):\(verse.verse)]" : "\(verse.chapter):\(verse.verse)"
            return "\(prefix) \(appModel.displayText(for: verse))"
        }
        .joined(separator: " ")
    }

    private var isSingleVerseSelection: Bool {
        selectedRangeVerses.count == 1
    }

    private var passageSections: [PassageSection] {
        PassageBreakdown.sections(for: selectedRangeVerses, translation: appModel.preferredTranslation == .esv ? .kjv : appModel.preferredTranslation)
    }

    private var passagePlan: PassagePlanSummary {
        PassageBreakdown.summary(
            for: selectedRangeVerses,
            translation: appModel.preferredTranslation == .esv ? .kjv : appModel.preferredTranslation
        )
    }

    private var showsSectionTextPreviews: Bool {
        appModel.preferredTranslation != .esv
    }

    private var primaryActionDisabled: Bool {
        switch saveMode {
        case .singleVerses:
            return false
        case .passage:
            return appModel.containsPassageUnit(reference: selectedRangeReference)
        case .sectionBundle:
            return appModel.containsSectionBundle(reference: selectedRangeReference)
        }
    }

    private var primaryActionTitle: String {
        switch saveMode {
        case .singleVerses:
            return "Add verses to My Verses"
        case .passage:
            return primaryActionDisabled ? "Passage already in My Verses" : "Add passage to My Verses (\(passagePlan.sectionLabel))"
        case .sectionBundle:
            return primaryActionDisabled ? "Section plan already in My Verses" : "Add section plan to My Verses (\(passagePlan.sectionLabel))"
        }
    }

    private var sectionBundleStrategyLine: String {
        if passageSections.count <= 1 {
            return "This range is compact enough to stay as one unit."
        }
        return "This range will be saved as \(passageSections.count) connected sections so you can move through the whole chapter or paragraph without carrying every verse at once."
    }

    private func performPrimaryAction() {
        switch saveMode {
        case .singleVerses:
            let addedUnits = appModel.addSingleVerseUnits(for: selectedRangeVerses, track: trackMode.studyTrack)
            guard !addedUnits.isEmpty else { return }
            let title = "Added \(addedUnits.count) verses"
            let message = trackMode == .scheduled
                ? "Those verses are ready in your daily queue."
                : "Those verses are saved for practice-only review."
            setAddFeedback(
                title: title,
                message: message,
                focusUnitIDs: addedUnits.map(\.id),
                focusReference: addedUnits.count == 1 ? addedUnits.first?.reference : "Selected verses"
            )
        case .passage:
            guard let unit = appModel.createPassageUnit(from: selectedRangeVerses, track: trackMode.studyTrack) else { return }
            let message = trackMode == .scheduled
                ? "This passage is ready in your daily queue."
                : "This passage is saved for focused practice outside the daily queue."
            setAddFeedback(
                title: "Passage added",
                message: message,
                focusUnitIDs: [unit.id],
                focusReference: unit.reference
            )
        case .sectionBundle:
            let units = appModel.createPassageSectionUnits(from: selectedRangeVerses, track: trackMode.studyTrack)
            guard !units.isEmpty else { return }
            let message = trackMode == .scheduled
                ? "This range was split into \(units.count) linked sections for your daily queue."
                : "This range was split into \(units.count) linked sections for focused practice."
            setAddFeedback(
                title: "Section plan added",
                message: message,
                focusUnitIDs: units.map(\.id),
                focusReference: selectedRangeReference
            )
        }
    }

    private func setAddFeedback(title: String, message: String, focusUnitIDs: [UUID], focusReference: String?) {
        withAnimation(.spring(duration: 0.42, bounce: 0.28)) {
            addFeedback = AddFeedback(
                title: title,
                message: message,
                focusUnitIDs: focusUnitIDs,
                focusReference: focusReference
            )
        }
    }

    @ViewBuilder
    private func addFeedbackCard(_ feedback: AddFeedback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(feedback.title)
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text(feedback.message)
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)

            HStack(spacing: 12) {
                if !feedback.focusUnitIDs.isEmpty {
                    Button("Practice now") {
                        let units = feedback.focusUnitIDs.compactMap(appModel.studyUnit(withID:))
                        let focusReference = feedback.focusReference ?? units.first?.reference ?? "Focused practice"
                        if let firstUnit = units.first, units.count == 1 {
                            appModel.startFocusedPractice(for: firstUnit)
                        } else {
                            appModel.startFocusedPractice(for: units, focusReference: focusReference)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("Keep browsing") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        addFeedback = nil
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .cardSurface()
    }

    private func resetSelectionForBook() {
        startChapter = chapterOptions.first ?? 1
        startVerse = 1
        endChapter = startChapter
        endVerse = startVerse
        normalizeSelection()
    }

    private func normalizeSelection() {
        let chapters = chapterOptions
        guard let firstChapter = chapters.first, let lastChapter = chapters.last else { return }

        startChapter = min(max(startChapter, firstChapter), lastChapter)
        endChapter = min(max(endChapter, startChapter), lastChapter)

        let maxStartVerse = BibleCatalog.lastVerseNumber(in: selectedBookID, chapter: startChapter)
        startVerse = min(max(startVerse, 1), maxStartVerse)

        let minEndVerse = endChapter == startChapter ? startVerse : 1
        let maxEndVerse = BibleCatalog.lastVerseNumber(in: selectedBookID, chapter: endChapter)
        endVerse = min(max(endVerse, minEndVerse), maxEndVerse)
    }
}

#Preview {
    VerseLibraryView()
        .environment(AppModel(progressStore: ReviewProgressStore.initialize(inMemory: true).store))
}
