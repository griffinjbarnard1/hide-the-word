import SwiftUI

struct PublicProfileEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var socialService = SocialService.shared

    @State private var profile = PublicProfile(id: "", displayName: "")
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var persistenceStatus: PublicProfilePersistenceStatus = .savedLocally

    var body: some View {
        Form {
            Section("Public profile") {
                TextField("Display name", text: displayNameBinding)
                characterCount(profile.displayName.count, max: PublicProfile.maxDisplayNameLength)

                TextField("Bio", text: bioBinding, axis: .vertical)
                    .lineLimit(3...5)
                characterCount(profile.bio.count, max: PublicProfile.maxBioLength)

                TextField("Favorite verse", text: favoriteVerseBinding, axis: .vertical)
                    .lineLimit(2...3)
                characterCount(profile.favoriteVerse.count, max: PublicProfile.maxFavoriteVerseLength)

                TextField("Avatar seed", text: avatarSeedBinding)
                characterCount(profile.avatarSeed.count, max: PublicProfile.maxAvatarSeedLength)
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Sync status") {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }

            Section {
                Text("Visible to collaborators in your shared plans.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
            }
        }
        .task { await loadProfile() }
        .navigationTitle("Edit my profile")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving…" : "Save") {
                    Task { await saveProfile() }
                }
                .disabled(isSaving || !profile.isValid)
            }
        }
    }

    private var displayNameBinding: Binding<String> {
        Binding(
            get: { profile.displayName },
            set: { profile.displayName = PublicProfile.clean($0, max: PublicProfile.maxDisplayNameLength) }
        )
    }

    private var bioBinding: Binding<String> {
        Binding(
            get: { profile.bio },
            set: { profile.bio = PublicProfile.clean($0, max: PublicProfile.maxBioLength) }
        )
    }

    private var favoriteVerseBinding: Binding<String> {
        Binding(
            get: { profile.favoriteVerse },
            set: { profile.favoriteVerse = PublicProfile.clean($0, max: PublicProfile.maxFavoriteVerseLength) }
        )
    }

    private var avatarSeedBinding: Binding<String> {
        Binding(
            get: { profile.avatarSeed },
            set: { profile.avatarSeed = PublicProfile.clean($0, max: PublicProfile.maxAvatarSeedLength) }
        )
    }

    private func loadProfile() async {
        profile = await socialService.fetchMyProfile(defaultDisplayName: appModel.userDisplayName)
        persistenceStatus = socialService.profilePersistenceStatus
    }

    private func saveProfile() async {
        isSaving = true
        saveError = nil
        let cleaned = PublicProfile(
            id: profile.id,
            displayName: profile.displayName,
            bio: profile.bio,
            favoriteVerse: profile.favoriteVerse,
            avatarSeed: profile.avatarSeed,
            updatedAt: .now
        )

        let didSave = await socialService.saveMyProfile(cleaned)
        isSaving = false
        if didSave {
            appModel.userDisplayName = cleaned.displayName
            persistenceStatus = socialService.profilePersistenceStatus
            dismiss()
        } else {
            saveError = socialService.lastError ?? "Could not save profile."
        }
    }

    private var statusText: String {
        switch persistenceStatus {
        case .savedLocally:
            return "Saved locally"
        case .syncedToSharedPlans:
            return "Synced to shared plans"
        }
    }

    private func characterCount(_ count: Int, max: Int) -> some View {
        Text("\(count)/\(max)")
            .font(.caption2)
            .foregroundStyle(Color.mutedText)
    }
}
