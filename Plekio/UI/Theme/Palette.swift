//
//  Palette.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.08.2026.
//

import SwiftUI
import UIKit

// MARK: - Helpers

/// A `Color` resolving per theme; optional variants for Increase Contrast.
private func adaptive(
    light: UIColor,
    dark: UIColor,
    lightIncreased: UIColor? = nil,
    darkIncreased: UIColor? = nil
) -> Color {
    Color(UIColor { traits in
        let increased = traits.accessibilityContrast == .high
        if traits.userInterfaceStyle == .dark {
            return increased ? (darkIncreased ?? dark) : dark
        }
        return increased ? (lightIncreased ?? light) : light
    })
}

private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
    UIColor(red: red, green: green, blue: blue, alpha: 1)
}

// MARK: - UITraitCollection

extension UITraitCollection {

    /// For resolving a system colour to its dark-theme value; also used by AppAppearance.
    static let darkAppearance = UITraitCollection(userInterfaceStyle: .dark)
}

// MARK: - Color Palette

extension Color {

    // MARK: - Surfaces

    /// Screen background.
    static let appBackground = adaptive(
        light: rgb(0.953, 0.945, 0.914),
        dark: rgb(0.06, 0.08, 0.12)
    )

    /// Cards and panels sitting on `appBackground`.
    static let appSurface = adaptive(
        light: rgb(1.0, 1.0, 1.0),
        dark: rgb(0.11, 0.13, 0.19)
    )

    /// Tile behind a medication icon when there is no photo.
    static let iconTile = adaptive(
        light: rgb(0.906, 0.941, 0.929),
        dark: rgb(1.0, 1.0, 1.0)
    )

    // MARK: - Ink

    /// Text and icons on a surface.
    static let textPrimary = adaptive(
        light: rgb(0.090, 0.106, 0.129),
        dark: rgb(1.0, 1.0, 1.0)
    )

    /// Labels and captions. Solid, not `textPrimary.opacity`: tuned to ~4.7:1 on
    /// tinted chips (just above WCAG AA) in both themes.
    static let textSecondary = adaptive(
        light: rgb(0.380, 0.396, 0.424),
        dark: rgb(0.553, 0.580, 0.624),
        lightIncreased: rgb(0.286, 0.302, 0.329),
        darkIncreased: rgb(0.659, 0.682, 0.722)
    )

    /// Disabled, decorative and placeholder content, held at ~3.2:1 (non-text AA floor).
    static let textTertiary = adaptive(
        light: rgb(0.518, 0.533, 0.561),
        dark: rgb(0.412, 0.439, 0.486),
        lightIncreased: rgb(0.392, 0.408, 0.435),
        darkIncreased: rgb(0.529, 0.557, 0.600)
    )

    /// Text and icons drawn on the accent fill.
    static let onAccent = adaptive(
        light: rgb(1.0, 1.0, 1.0),
        dark: rgb(0.06, 0.08, 0.12)
    )

    // MARK: - Accent

    /// The only name for the accent; don't use `Color.mint` directly.
    /// Keep in sync with `Assets.xcassets/AccentColor` (used by UIKit controls).
    static let accentPrimary = Color(UIColor.appAccent)

    /// Companion to the accent for gradients (progress ring).
    static let accentSecondary = adaptive(
        light: rgb(0.180, 0.561, 0.518),
        dark: UIColor.systemTeal.resolvedColor(with: .darkAppearance)
    )

    /// Accent for diary milestone tags.
    static let milestonePurple = adaptive(
        light: rgb(0.420, 0.247, 0.627),
        dark: rgb(0.7, 0.4, 0.9)
    )

    // MARK: - Status

    /// Low-stock amber.
    static let warningAmber = adaptive(
        light: rgb(0.541, 0.380, 0.0),
        dark: UIColor.systemYellow.resolvedColor(with: .darkAppearance)
    )

    /// The "after"/energy counterpart to the accent.
    static let warmAccent = adaptive(
        light: rgb(0.761, 0.380, 0.039),
        dark: UIColor.systemOrange.resolvedColor(with: .darkAppearance)
    )

    /// Background for the low-stock warning.
    static let warningBg = adaptive(
        light: rgb(0.984, 0.925, 0.918),
        dark: rgb(0.2, 0.05, 0.08)
    )

    /// Also the danger colour (missed, delete); system red fails AA on light cards.
    static let warningAccent = adaptive(
        light: rgb(0.753, 0.224, 0.169),
        dark: rgb(0.922, 0.451, 0.439)
    )

    /// Dose-card overlays; alpha is set per theme since one alpha can't suit both.
    static let missedWash = adaptive(
        light: UIColor(red: 0.753, green: 0.224, blue: 0.169, alpha: 0.07),
        dark: UIColor(red: 0.922, green: 0.451, blue: 0.439, alpha: 0.13)
    )

    /// Neutral: a skip is a choice and must not look as urgent as a missed dose.
    static let skippedWash = adaptive(
        light: UIColor(white: 0.35, alpha: 0.07),
        dark: UIColor(white: 1, alpha: 0.10)
    )

    // MARK: - Effects

    /// Drop shadow under a modal.
    static let appShadow = adaptive(
        light: UIColor.black.withAlphaComponent(0.14),
        dark: UIColor.black.withAlphaComponent(0.6)
    )

    /// Corner tint of the splash gradient.
    static let splashTint = adaptive(
        light: rgb(0.843, 0.910, 0.878),
        dark: rgb(0.05, 0.25, 0.22)
    )

    // MARK: - Hero Card

    // Hero label is white in both themes, so light variants are deeper, not lighter.

    /// Morning: sage moving into olive.
    static let heroMorningStart = adaptive(
        light: rgb(0.455, 0.522, 0.247),
        dark: UIColor.systemMint.resolvedColor(with: .darkAppearance)
    )
    static let heroMorningEnd = adaptive(
        light: rgb(0.325, 0.420, 0.224),
        dark: UIColor.systemTeal.resolvedColor(with: .darkAppearance)
    )

    /// Midday: amber moving into terracotta.
    static let heroNoonStart = adaptive(
        light: rgb(0.690, 0.478, 0.133),
        dark: UIColor.systemOrange.resolvedColor(with: .darkAppearance)
    )
    static let heroNoonEnd = adaptive(
        light: rgb(0.561, 0.318, 0.090),
        dark: UIColor.systemYellow.resolvedColor(with: .darkAppearance)
    )

    /// Evening: plum moving into poppy, muted enough to keep white text readable.
    static let heroEveningStart = adaptive(
        light: rgb(0.431, 0.353, 0.651),
        dark: UIColor.systemPurple.resolvedColor(with: .darkAppearance)
    )
    static let heroEveningEnd = adaptive(
        light: rgb(0.780, 0.267, 0.180),
        dark: UIColor.systemIndigo.resolvedColor(with: .darkAppearance)
    )
}
