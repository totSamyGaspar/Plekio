//
//  ProfileSection.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI

/// The profile row at the top of Settings, read straight from `@AppStorage`.
struct ProfileSection: View {

    // MARK: - Properties

    @AppStorage(UserProfile.storageKey) private var stored = StoredProfile(.empty)
    @State private var isEditing = false

    // MARK: - Body

    var body: some View {
        Section(header: Text("Profile").foregroundColor(.textSecondary)) {
            Button { isEditing = true } label: {
                HStack(spacing: 14) {
                    ProfileAvatar(id: stored.profile.avatarId, side: 52)
                    titles
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 4)
            }
            // On the row, not the Section: a Section applies it to every row and the
            // header, and two sheets on one flag trigger "already presenting".
            .sheet(isPresented: $isEditing) {
                ProfileEditView(profile: $stored.profile)
            }
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            if stored.profile.name.isEmpty {
                Text("Add your details")
                    .foregroundColor(.textSecondary)
            } else {
                Text(stored.profile.name)
                    .foregroundColor(.textPrimary)
            }

            // The date, not the age: it localises without plural forms.
            if let birthDate = stored.profile.birthDate {
                Text(birthDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
        }
    }
}
