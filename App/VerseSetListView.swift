import SwiftUI
import ScriptureMemory

struct VerseSetListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(BuiltInContent.verseSets, id: \.id) { collection in
                    Button {
                        appModel.selectCollection(collection.id)
                        appModel.activeRoute = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                Image(systemName: collection.systemImageName)
                                    .foregroundStyle(Color.accentGold)
                                Text(collection.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                if appModel.selectedCollectionID == collection.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentMoss)
                                }
                            }

                            Text(collection.summary)
                                .font(.subheadline)
                                .foregroundStyle(Color.mutedText)

                            Text(detailLine(for: collection))
                                .font(.caption)
                                .foregroundStyle(Color.accentMoss)

                            HStack(spacing: 8) {
                                StatusPill(title: sessionLine(for: collection))
                                if appModel.selectedCollectionID == collection.id {
                                    StatusPill(title: "Current", tint: .accentGold)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface()
                    }
                    .buttonStyle(ScalableCardButtonStyle())
                }

                if appModel.selectedCollectionID == BuiltInContent.myVersesSetID {
                    Button("Open Bible Library") {
                        appModel.openVerseLibrary()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(24)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    appModel.dismissActiveRoute()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collections")
                .font(.largeTitle.weight(.semibold))
            Text("Choose the group that should drive your next session.")
                .foregroundStyle(Color.mutedText)
        }
    }

    private func detailLine(for collection: VerseSet) -> String {
        let count: Int
        if collection.id == BuiltInContent.myVersesSetID {
            count = appModel.scheduledCustomStudyUnits.count
        } else {
            count = BuiltInContent.builtInStudyUnits(for: collection.id).count
        }

        if collection.isCustom {
            let scheduledCount = appModel.scheduledCustomStudyUnits.count
            let practiceCount = appModel.practiceOnlyCustomStudyUnits.count
            let bundleCount = appModel.customSectionBundleSummaries.count
            if scheduledCount == 0 && practiceCount == 0 {
                return "No study units picked yet"
            }
            if bundleCount > 0 {
                return "\(scheduledCount) scheduled • \(practiceCount) practice-only • \(bundleCount) linked plans"
            }
            return "\(scheduledCount) scheduled • \(practiceCount) practice-only"
        }

        let unitLabel = count == 1 ? "unit" : "units"
        return "\(count) \(unitLabel) in this collection"
    }

    private func sessionLine(for collection: VerseSet) -> String {
        let units: [StudyUnit]
        if collection.id == BuiltInContent.myVersesSetID {
            units = appModel.scheduledCustomStudyUnits
        } else {
            units = BuiltInContent.builtInStudyUnits(for: collection.id)
        }

        let dueCount = units.filter { unit in
            guard let progress = appModel.progressByVerseID[unit.id] else { return false }
            return progress.isDue(on: .now)
        }.count
        let hasNew = units.contains { !(appModel.progressByVerseID[$0.id]?.isStarted ?? false) }

        if dueCount == 0 && !hasNew {
            return "Light review only"
        }

        if hasNew {
            return dueCount == 0 ? "New unit ready" : "\(dueCount) due + 1 new"
        }

        return dueCount == 1 ? "1 review due" : "\(dueCount) reviews due"
    }
}

#Preview {
    VerseSetListView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
}
