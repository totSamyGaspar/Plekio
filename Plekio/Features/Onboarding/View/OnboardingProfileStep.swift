//
//  OnboardingProfileStep.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI

/// Final onboarding step asking for the profile name and date of birth.
/// Kept outside the carousel: a form inside a paged TabView fights the swipe.
struct OnboardingProfileStep: View {

    // MARK: - Properties

    /// Saved as typed; Skip clears it rather than rolling back.
    @AppStorage(UserProfile.storageKey) private var stored = StoredProfile(.empty)

    let onFinish: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            header
            fields
            Spacer()
            buttons
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 16) {
            AppLogo(size: 62)

            Text("Who is this for?")
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Text("Reports you share later will carry these details. You can change them any time in Settings.")
                .font(.body)
                .foregroundColor(.textPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var fields: some View {
        VStack(spacing: 0) {
            TextField("Name", text: $stored.profile.name)
                .foregroundColor(.textPrimary)
                .textContentType(.name)
                .padding(.horizontal, 16)
                .frame(height: 52)

            Divider().overlay(Color.textPrimary.opacity(0.1))

            Toggle("Date of birth", isOn: $stored.profile.isBirthDateSet)
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 52)

            if stored.profile.birthDate != nil {
                Divider().overlay(Color.textPrimary.opacity(0.1))

                DatePicker(
                    "Date of birth",
                    selection: $stored.profile.birthDateOrDefault,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .appColorScheme()
                .padding(.horizontal, 16)
                .frame(height: 52, alignment: .leading)
            }
        }
        .background(Color.appSurface)
        .clipShape(.rect(cornerRadius: 16))
        .tint(.accentPrimary)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button(action: onFinish) {
                // Own key, not "Start", which translates as a noun in Ukrainian.
                Text("Get started")
            }
            .buttonStyle(OnboardingButtonStyle())

            Button {
                // Discard half-typed input so it never heads an exported report.
                stored = StoredProfile(.empty)
                onFinish()
            } label: {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.bottom, 40)
    }
}
