//
//  OnboardingStyle.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.09.2026.
//

import SwiftUI

// MARK: - View Modifiers

/// Onboarding chrome, built from the palette so it follows the light/dark theme.
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

// MARK: - OnboardingCaption

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

// MARK: - OnboardingButtonStyle

/// The 56-point pill for primary onboarding actions. Uses `onAccent`, not white,
/// for legibility on the light theme's accent.
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
