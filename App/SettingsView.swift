import SwiftUI
import ScriptureMemory

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    private let socialService = SocialService.shared
    @State private var identityStatus: SharedPlanManager.IdentityStatus = .unavailable
    @State private var cloudKitIdentity: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "settings.title", defaultValue: "Settings", table: "Localizable"))
                        .font(.title.weight(.semibold))
                    Text(String(localized: "settings.subtitle", defaultValue: "Keep preferences simple and local. These choices shape what you see throughout the app.", table: "Localizable"))
                        .font(.subheadline)
                        .foregroundStyle(Color.mutedText)
                }
                .listRowBackground(Color.screenBackground)
                .listRowSeparator(.hidden)
            }

            Section(String(localized: "settings.section.translation", defaultValue: "Preferred Translation", table: "Localizable")) {
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

            Section(String(localized: "settings.section.appearance", defaultValue: "Appearance", table: "Localizable")) {
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

            Section(String(localized: "settings.section.session_size", defaultValue: "Session Size", table: "Localizable")) {
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

            Section(String(localized: "settings.section.reminder", defaultValue: "Daily Reminder", table: "Localizable")) {
                Toggle(String(localized: "settings.reminder.toggle", defaultValue: "Remind me to review", table: "Localizable"), isOn: Binding(
                    get: { appModel.reminderEnabled },
                    set: { appModel.setReminderEnabled($0) }
                ))
                .tint(Color.accentMoss)

                if appModel.reminderEnabled {
                    DatePicker(
                        String(localized: "settings.reminder.time", defaultValue: "Reminder time", table: "Localizable"),
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

            Section(String(localized: "settings.section.recall_mode", defaultValue: "Recall Mode", table: "Localizable")) {
                Toggle(String(localized: "settings.recall.toggle", defaultValue: "Type to recall", table: "Localizable"), isOn: Binding(
                    get: { appModel.typeRecallEnabled },
                    set: { appModel.setTypeRecallEnabled($0) }
                ))
                .tint(Color.accentMoss)

                if appModel.typeRecallEnabled {
                    Text(String(localized: "settings.recall.body", defaultValue: "Recall screens switch from progressive masking to typed recall with light prompts.", table: "Localizable"))
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }
            }

            Section(String(localized: "settings.section.display_name", defaultValue: "Display Name", table: "Localizable")) {
                TextField(String(localized: "settings.display_name.placeholder", defaultValue: "Your name", table: "Localizable"), text: Binding(
                    get: { appModel.userDisplayName },
                    set: { appModel.userDisplayName = $0 }
                ))
                Text(String(localized: "settings.display_name.caption", defaultValue: "Shown to people in shared plans.", table: "Localizable"))
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            Section(String(localized: "settings.section.profile", defaultValue: "Profile", table: "Localizable")) {
                NavigationLink(String(localized: "settings.profile.edit", defaultValue: "Edit my profile", table: "Localizable")) {
                    PublicProfileEditorView()
                }
            }

            Section(String(localized: "settings.section.identity", defaultValue: "Identity", table: "Localizable")) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "settings.identity.connected", defaultValue: "Connected account", table: "Localizable"))
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

                Text(String(localized: "settings.identity.caption", defaultValue: "Hide the Word has no separate app login. Sharing and sync use your iCloud account.", table: "Localizable"))
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            Section(String(localized: "settings.section.data", defaultValue: "Data", table: "Localizable")) {
                if let exportURL = appModel.exportDataURL() {
                    ShareLink(item: exportURL) {
                        Label(String(localized: "settings.data.export", defaultValue: "Export all data", table: "Localizable"), systemImage: "square.and.arrow.up")
                    }
                    Text(String(localized: "settings.data.caption", defaultValue: "Exports your progress, custom verses, and preferences as a JSON file.", table: "Localizable"))
                        .font(.caption)
                        .foregroundStyle(Color.mutedText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.screenBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common.done", defaultValue: "Done", table: "Localizable")) {
                    appModel.dismissActiveRoute()
                }
            }
        }
        .task {
            let snapshot = await socialService.identitySnapshot()
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
