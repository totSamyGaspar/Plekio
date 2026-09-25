//
//  OnboardingStyle.swift
//  Plekio
//

import SwiftUI

/// Chrome shared by the onboarding slides.
///
/// Built from the palette rather than from the mockup's constants. The design
/// was drawn dark, but the app has a light theme, and a slide painted in
/// dark-theme hexes would be the one screen that refuses to follow it.
extension View {

    func onboardingCard(_ padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        self
            .padding(padding)
            .background(Color.appSurface)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.textPrimary.opacity(0.08), lineWidth: 1)
            )
    }

    /// The tinted pill behind a value: a time, a dose, a measurement.
    func onboardingChip() -> some View {
        self
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color.textPrimary.opacity(0.07))
            .clipShape(.capsule)
    }
}

/// The small all-caps label above a block.
struct OnboardingCaption: View {

    let text: LocalizedStringResource

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundColor(.textSecondary)
    }
}

/// The 56-point pill every primary action in onboarding uses.
///
/// `onAccent` rather than white: the light theme's accent is a deep teal, and
/// white on it is the one combination that fails to read.
struct OnboardingButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.onAccent)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.accentPrimary)
            .clipShape(.capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
