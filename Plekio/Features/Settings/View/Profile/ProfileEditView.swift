//
//  ProfileEditView.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI
import os

/// The profile form. Edits apply immediately with no Cancel: replacing the avatar
/// deletes the old file, so rolling back would point at a photo already gone.
struct ProfileEditView: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies

    @Binding var profile: UserProfile

    @Environment(\.dismiss) private var dismiss

    @State private var isChoosingSource = false

    /// Made once per sheet so a slow write cannot overwrite a newer pick or removal.
    @State private var avatars: ProfileAvatarEditor?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    avatarSection
                    identitySection
                    healthSection
                }
                .scrollContentBackground(.hidden)
                .tint(.accentPrimary)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.accentPrimary)
                }
            }
            .photoSourceDialog("Photo", isPresented: $isChoosingSource, onPick: saveAvatar) {
                if profile.avatarId != nil {
                    Button("Remove photo", role: .destructive, action: removeAvatar)
                }
            }
        }
        .appTheme()
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            Button { isChoosingSource = true } label: {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProfileAvatar(id: profile.avatarId, side: 96)
                        Text(profile.avatarId == nil ? "Add Photo" : "Change photo")
                            .font(.subheadline)
                            .foregroundColor(.accentPrimary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color.appSurface)
    }

    private var identitySection: some View {
        Section(header: Text("Name").foregroundColor(.textSecondary)) {
            TextField("Name", text: $profile.name)
                .foregroundColor(.textPrimary)
                .textContentType(.name)

            Toggle("Date of birth", isOn: $profile.isBirthDateSet)
                .foregroundColor(.textPrimary)

            if profile.birthDate != nil {
                DatePicker(
                    "Date of birth",
                    selection: $profile.birthDateOrDefault,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .foregroundColor(.textPrimary)
                .labelsHidden()
                .appColorScheme()
            }
        }
        .listRowBackground(Color.appSurface)
    }

    private var healthSection: some View {
        Section(header: Text("Health").foregroundColor(.textSecondary)) {
            field("Allergies", text: $profile.allergies)
            field("Chronic conditions", text: $profile.conditions)
        }
        .listRowBackground(Color.appSurface)
    }

    private func field(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            TextField(title, text: text, axis: .vertical)
                .foregroundColor(.textPrimary)
                .lineLimit(1...4)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Avatar

    private var avatarEditor: ProfileAvatarEditor {
        if let avatars { return avatars }
        let editor = dependencies.makeProfileAvatarEditor()
        avatars = editor
        return editor
    }

    private func saveAvatar(_ image: UIImage) {
        let editor = avatarEditor
        let current = profile.avatarId
        Task {
            if let saved = await editor.replace(current, with: image) {
                profile.avatarId = saved
            }
        }
    }

    private func removeAvatar() {
        let editor = avatarEditor
        let current = profile.avatarId
        profile.avatarId = nil
        Task { await editor.remove(current) }
    }
}
