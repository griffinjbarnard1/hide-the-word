import SwiftUI
import ScriptureMemory

struct CreatePlanView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedBookID: String?
    @State private var selectedChapter: Int?
    @State private var selectedVerses: [VerseReference] = []
    @State private var generatedDays: [PlanDay] = []
    @State private var showingPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                detailsSection
                versePickerSection
                if !selectedVerses.isEmpty {
                    selectedVersesSection
                    previewSection
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .navigationTitle("Create Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { savePlan() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
        .onChange(of: selectedVerses) {
            generatedDays = PlanDayGenerator.generateDays(from: selectedVerses)
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan Details")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            TextField("Plan title", text: $title)
                .font(.body)
                .padding(12)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            TextField("Short description (optional)", text: $description)
                .font(.body)
                .padding(12)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Verse Picker

    private var versePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Verses")
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            // Book picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BibleCatalog.books) { book in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedBookID = book.id
                                selectedChapter = nil
                            }
                        } label: {
                            Text(book.name)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedBookID == book.id ? Color.accentMoss : Color.paper)
                                .foregroundStyle(selectedBookID == book.id ? .white : Color.primaryText)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Chapter picker
            if let bookID = selectedBookID {
                let chapters = BibleCatalog.chapterNumbers(in: bookID)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chapters, id: \.self) { chapter in
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedChapter = chapter
                                }
                            } label: {
                                Text("\(chapter)")
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 36, height: 36)
                                    .background(selectedChapter == chapter ? Color.accentGold : Color.paper)
                                    .foregroundStyle(selectedChapter == chapter ? .white : Color.primaryText)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }

            // Verse grid
            if let bookID = selectedBookID, let chapter = selectedChapter {
                let lastVerse = BibleCatalog.lastVerseNumber(in: bookID, chapter: chapter)
                let verses = Array(1...max(lastVerse, 1))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(verses, id: \.self) { verse in
                        let ref = VerseReference(bookID: bookID, chapter: chapter, verse: verse)
                        let isSelected = selectedVerses.contains(ref)

                        Button {
                            toggleVerse(ref)
                        } label: {
                            Text("\(verse)")
                                .font(.caption2.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(isSelected ? Color.accentMoss : Color.paper)
                                .foregroundStyle(isSelected ? .white : Color.primaryText)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }

                // Quick range buttons
                HStack(spacing: 8) {
                    Button("Select all") {
                        for v in 1...max(lastVerse, 1) {
                            let ref = VerseReference(bookID: bookID, chapter: chapter, verse: v)
                            if !selectedVerses.contains(ref) {
                                selectedVerses.append(ref)
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))

                    Button("Clear chapter") {
                        selectedVerses.removeAll { $0.bookID == bookID && $0.chapter == chapter }
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                }
            }
        }
    }

    // MARK: - Selected Verses

    private var selectedVersesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(selectedVerses.count) verse\(selectedVerses.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentMoss)
            }

            FlowLayoutView(spacing: 6) {
                ForEach(Array(selectedVerses.enumerated()), id: \.offset) { _, ref in
                    HStack(spacing: 4) {
                        Text(ref.displayReference)
                            .font(.caption2.weight(.semibold))
                        Button {
                            selectedVerses.removeAll { $0 == ref }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentMoss.opacity(0.15))
                    .foregroundStyle(Color.accentMoss)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Day Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Day Breakdown")
                    .font(.headline)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(generatedDays.count) days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentGold)
            }

            Text("Auto-generated: ~2 verses per day with review days every 3rd day and a full recall day at the end.")
                .font(.caption)
                .foregroundStyle(Color.mutedText)

            ForEach(generatedDays) { day in
                HStack(spacing: 10) {
                    Circle()
                        .fill(day.goal == .reviewOnly ? Color.accentGold.opacity(0.3) : day.goal == .fullRecall ? Color.accentMoss.opacity(0.3) : Color.accentMoss)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Text("\(day.dayNumber)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(day.goal == .learnNew ? .white : Color.primaryText)
                        }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(day.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.primaryText)
                        Text(goalLabel(day.goal))
                            .font(.caption2)
                            .foregroundStyle(Color.mutedText)
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Helpers

    private func toggleVerse(_ ref: VerseReference) {
        if let index = selectedVerses.firstIndex(of: ref) {
            selectedVerses.remove(at: index)
        } else {
            selectedVerses.append(ref)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !selectedVerses.isEmpty
    }

    private func savePlan() {
        let plan = MemorizationPlan(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces).isEmpty
                ? "\(selectedVerses.count) verses over \(generatedDays.count) days"
                : description.trimmingCharacters(in: .whitespaces),
            systemImageName: "square.grid.2x2",
            category: .custom,
            days: generatedDays,
            isBuiltIn: false
        )

        appModel.saveCustomPlan(plan)
        appModel.enrollInPlan(plan)
        dismiss()
    }

    private func goalLabel(_ goal: PlanDayGoal) -> String {
        switch goal {
        case .learnNew: return "New material"
        case .reviewOnly: return "Review day"
        case .fullRecall: return "Full recall"
        case .rest: return "Rest day"
        }
    }
}

/// Simple flow layout for verse chips
struct FlowLayoutView<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        _FlowLayout(spacing: spacing) {
            content()
        }
    }
}

struct _FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
