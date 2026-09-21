//
//  ProfileSection.swift
//  Plekio
//

import SwiftUI

/// Who the app is for, at the top of Settings.
///
/// Reads the profile straight out of `@AppStorage` rather than through an
/// observable object, the way the theme picker below it does.
struct ProfileSection: View {

    @AppStorage(UserProfile.storageKey) private var stored = StoredProfile(.empty)
    @State private var isEditing = false

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
            // On the row, not on the Section: a modifier written on a Section is
            // applied to each of its rows, the header included, and two
            // presentations driven by one flag is what UIKit reports as
            // "already presenting".
            .sheet(isPresented: $isEditing) {
                ProfileEditView(profile: $stored.profile)
            }
        }
        .listRowBackground(Color.appSurface)
    }

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

            // The date, not the age: a formatted date localises itself, where a
            // count of years would need plural forms in all nine languages to
            // say the same thing.
            if let birthDate = stored.profile.birthDate {
                Text(birthDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
        }
    }
}
