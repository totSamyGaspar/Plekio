//
//  ProfileEditView.swift
//  Plekio
//

import SwiftUI
import os
/// The profile form.
///
/// Edits apply as they are made, like every other row in Settings — there is no
/// Save. That is not only for brevity: replacing the avatar has to delete the
/// file it replaces, and a Cancel that rolled the profile back would leave it
/// pointing at a photo already gone from disk.
struct ProfileEditView: View {

    @Binding var profile: UserProfile

    @Environment(\.dismiss) private var dismiss

    @State private var isChoosingSource = false

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
            // A dialog at screen level rather than a Menu on the row: this is
            // how the medication and diary screens already ask the same
            // question, and a menu inside a form inside a sheet is a third
            // presentation stacked on two.
            .confirmationDialog("Photo", isPresented: $isChoosingSource, titleVisibility: .visible) {
                Button("Take Photo (Camera)") { pick(from: .camera) }
                Button("Choose from Library") { pick(from: .photoLibrary) }

                if profile.avatarId != nil {
                    Button("Remove photo", role: .destructive, action: removeAvatar)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .appTheme()
    }

    // MARK: - Sections

    /// The picture itself is the control — tapping the caption and not the photo
    /// is not what anyone tries first.
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

    private func pick(from source: MediaSource) {
        Task {
            do {
                let picker = DIContainer.shared.resolve(MediaPickerServiceProtocol.self)
                let image = try await picker.pickImage(source: source)
                let previous = profile.avatarId

                // Encoding and the two file operations all happen off the main
                // actor; only the resulting id comes back to the form.
                let saved = await Task.detached(priority: .userInitiated) {
                    AvatarStore.save(image, replacing: previous)
                }.value

                guard let saved else {
                    AppLog.media.error("Avatar could not be stored; the profile keeps its previous photo")
                    return
                }
                profile.avatarId = saved
            } catch {
                AppLog.media.error("Avatar selection failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func removeAvatar() {
        let previous = profile.avatarId
        profile.avatarId = nil
        Task.detached(priority: .utility) { AvatarStore.remove(previous) }
    }
}
