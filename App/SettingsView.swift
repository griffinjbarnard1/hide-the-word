import SwiftUI
import ScriptureMemory

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    private let sharedPlanManager = SharedPlanManager()
    @State private var identityStatus: SharedPlanManager.IdentityStatus = .unavailable
    @State private var cloudKitIdentity: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings")
                        .font(.title.weight(.semibold))
                    Text("Keep preferences simple and local. These choices shape what you see throughout the app.")
                        .font(.subheadline)
                        .foregroundStyle(Color.mutedText)
                }
                .listRowBackground(Color.screenBackground)
                .listRowSeparator(.hidden)
            }

            Section("Preferred Translation") {
                ForEach(BibleTranslation.allCases) { translation in
                    Button {
                        appModel.setPreferredTranslation(translation)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(translation.shortName)
                                    .foregroundStyle(Color.primaryText)
                                Text(translation.displayName)
                                    .font(.caption)
                                    .foregroundStyle(Color.mutedText)
                                if translation == .esv {
                                    Text(appModel.isESVConfigured ? "Fetched from Crossway at runtime." : "Needs `ESV_API_KEY` for live text.")
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentMoss)
                                }
                            }
                            Spacer()
                            if appModel.preferredTranslation == translation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentMoss)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let preferredTranslationStatusText = appModel.preferredTranslationStatusText {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferredTranslationStatusText)
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                        Link("Get an ESV API key", destination: URL(string: "https://api.esv.org/")!)
                            .font(.caption.weight(.semibold))
                    }
                    .listRowBackground(Color.paper)
                }
            }

            Section("Appearance") {
                ForEach(AppAppearance.allCases) { appearance in
                    Button {
                        appModel.setAppearance(appearance)
                    } label: {
                        HStack {
                            Text(appearance.title)
                                .foregroundStyle(Color.primaryText)
                            Spacer()
                            if appModel.appearance == appearance {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentMoss)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Session Size") {
                ForEach(SessionSizePreset.allCases) { preset in
                    Button {
                        appModel.setSessionSizePreset(preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.title)
                                    .foregroundStyle(Color.primaryText)
                                Text(preset.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.mutedText)
                            }
                            Spacer()
                            if appModel.sessionSizePreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentMoss)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Daily Reminder") {
                Toggle("Remind me to review", isOn: Binding(
                    get: { appModel.reminderEnabled },
                    set: { appModel.setReminderEnabled($0) }
                ))
                .tint(Color.accentMoss)

                if appModel.reminderEnabled {
                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: {
                                var components = DateComponents()
                                components.hour = appModel.reminderHour
                                components.minute = appModel.reminderMinute
                                return Calendar.current.date(from: components) ?? .now
                            },
                            set: { date in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                appModel.setReminderTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section("Recall Mode") {
                Toggle("Type to recall", isOn: Binding(
                    get: { appModel.typeRecallEnabled },
                    set: { appModel.setTypeRecallEnabled($0) }
                ))
                .tint(Color.accentMoss)

                if appModel.typeRecallEnabled {
                    Text("Recall screens switch from progressive masking to typed recall with light prompts.")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }
            }

            Section("Display Name") {
                TextField("Your name", text: Binding(
                    get: { appModel.userDisplayName },
                    set: { appModel.userDisplayName = $0 }
                ))
                Text("Shown to friends in shared journeys.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            Section("Identity") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Connected account")
                            .foregroundStyle(Color.primaryText)
                        Text("iCloud: \(identityStatusLabel)")
                            .font(.caption)
                            .foregroundStyle(Color.mutedText)
                    }
                    Spacer()
                    Text(cloudKitIdentity ?? "Not available")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                        .multilineTextAlignment(.trailing)
                }

                Text("Hide the Word has no separate app login. Sharing and sync use your iCloud account.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            Section("Data") {
                if let exportURL = appModel.exportDataURL() {
                    ShareLink(item: exportURL) {
                        Label("Export all data", systemImage: "square.and.arrow.up")
                    }
                    Text("Exports your progress, custom verses, and preferences as a JSON file.")
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.screenBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    appModel.dismissActiveRoute()
                }
            }
        }
        .task {
            let snapshot = await sharedPlanManager.identitySnapshot()
            identityStatus = snapshot.status
            cloudKitIdentity = snapshot.resolvedIdentity
        }
    }

    private var identityStatusLabel: String {
        switch identityStatus {
        case .available:
            return "Available"
        case .unavailable:
            return "Unavailable"
        case .restricted:
            return "Restricted"
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
}
