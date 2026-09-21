//
//  OnboardingProfileStep.swift
//  Plekio
//

import SwiftUI

/// The last thing onboarding asks: who the app is for.
///
/// After the carousel rather than as a fourth page in it — a form inside a
/// horizontally paged TabView fights the swipe, and page dots beside text
/// fields read as a mistake.
///
/// Two fields only. Allergies, conditions and the photo live in Settings: a
/// first launch is the worst moment to put four fields in front of someone who
/// has not seen the app yet.
struct OnboardingProfileStep: View {

    /// Written to storage as it is typed, like the settings form. There is a
    /// Skip here, not a Cancel, and Skip clears rather than rolls back.
    @AppStorage(UserProfile.storageKey) private var stored = StoredProfile(.empty)

    let onFinish: () -> Void

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

    // MARK: - Parts

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentPrimary, .accentPrimary.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

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
                Text("Start")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentPrimary)
                    .cornerRadius(16)
                    .shadow(color: Color.accentPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
            }

            Button {
                // Skip means skip: a half-typed name should not be what the
                // first exported document is headed with.
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
