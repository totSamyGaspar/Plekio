//
//  Palette.swift
//  PillFlow
//

import SwiftUI
import UIKit

//  Every colour the app uses, and the one place a light and a dark value are
//  paired.
//
//  Nothing here decides anything — it is the vocabulary the rest of the app
//  paints with. Which of the two values is served is AppTheme's business.

// MARK: - Palette

/// Resolves against the trait collection, so one `Color` covers both themes and
/// every existing call site switches with the app instead of being duplicated
/// per scheme.
///
/// The increased-contrast variants are optional and answer the system's
/// "Increase Contrast" setting. Only the muted tokens need them — they are the
/// ones sitting near the AA floor by design; everything else is already far
/// above it and would only get harsher.
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

extension UITraitCollection {

    /// For resolving a system colour to the value it takes in the dark theme.
    ///
    /// Namespaced rather than a private file-level constant: the UIKit twins in
    /// AppAppearance need it too, and `private` in Swift means "this file", which
    /// is exactly what splitting Theme.swift ran into.
    static let darkAppearance = UITraitCollection(userInterfaceStyle: .dark)
}

extension Color {

    // MARK: Surfaces

    /// The screen behind everything: near-black in the dark theme, warm off-white
    /// in the light one.
    static let appBackground = adaptive(
        light: rgb(0.953, 0.945, 0.914),
        dark: rgb(0.06, 0.08, 0.12)
    )

    /// Cards and panels sitting on `appBackground`.
    static let appSurface = adaptive(
        light: rgb(1.0, 1.0, 1.0),
        dark: rgb(0.11, 0.13, 0.19)
    )

    /// Backing tile behind a medication icon when there is no photo. White reads
    /// as a tile on a dark card but disappears on a white one, so the light
    /// theme uses a tinted square instead.
    static let iconTile = adaptive(
        light: rgb(0.906, 0.941, 0.929),
        dark: rgb(1.0, 1.0, 1.0)
    )

    // MARK: Ink

    /// Every piece of text and every icon drawn on a surface. Call sites keep
    /// their `.opacity(...)` steps: the same ratios that made white text recede
    /// on the dark theme make dark ink recede on the light one.
    static let textPrimary = adaptive(
        light: rgb(0.090, 0.106, 0.129),
        dark: rgb(1.0, 1.0, 1.0)
    )

    /// Secondary text: labels, captions, section headers — everything that
    /// recedes but still has to be read.
    ///
    /// Deliberately a solid color rather than a step on `textPrimary.opacity`.
    /// The same opacity means different contrast in each theme, because ink and
    /// ground swap roles: 0.5 held 5.0:1 on the dark card but only 3.2:1 on the
    /// cream one, so the ladder quietly failed everywhere the light theme went.
    /// Fixed here at ~4.7:1 on the tinted chip fills this text actually sits on,
    /// which is stricter than it looks: measured against the clean surfaces
    /// alone it came to 4.49 on a chip, and Accessibility Inspector caught the
    /// hundredth. Still only just over the AA floor, so text darkens no more
    /// than legibility requires.
    static let textSecondary = adaptive(
        light: rgb(0.380, 0.396, 0.424),
        dark: rgb(0.553, 0.580, 0.624),
        lightIncreased: rgb(0.286, 0.302, 0.329),
        darkIncreased: rgb(0.659, 0.682, 0.722)
    )

    /// Tertiary: disabled controls, decorative glyphs, placeholder text. Held at
    /// ~3.2:1 — the floor for non-text and large text, and low enough to still
    /// read as inactive.
    /// Under Increase Contrast it steps up to the normal secondary value, which
    /// is exactly one level of the hierarchy — muted text stops being muted
    /// rather than becoming a second primary.
    static let textTertiary = adaptive(
        light: rgb(0.518, 0.533, 0.561),
        dark: rgb(0.412, 0.439, 0.486),
        lightIncreased: rgb(0.392, 0.408, 0.435),
        darkIncreased: rgb(0.529, 0.557, 0.600)
    )

    /// Text and icons drawn *on* the accent fill, where the contrast runs the
    /// other way: the dark theme's accent is a light mint, the light theme's is
    /// a deep teal.
    static let onAccent = adaptive(
        light: rgb(1.0, 1.0, 1.0),
        dark: rgb(0.06, 0.08, 0.12)
    )

    // MARK: Accent

    /// The primary accent, under one name. Referenced under two — a custom one and
    /// SwiftUI's own `Color.mint` — changing the accent stops working.
    /// `accentPrimary` is now the only name for it.
    ///
    /// The light theme darkens it: system mint on white sits far below the
    /// contrast floor for text and small icons.
    /// Mirrored in `Assets.xcassets/AccentColor` so UIKit-provided controls the
    /// app never tints by hand — alert buttons, the caret in a text field,
    /// swipe actions — match instead of falling back to system blue.
    static let accentPrimary = Color(UIColor.appAccent)

    /// Companion to the accent for gradients (progress ring).
    static let accentSecondary = adaptive(
        light: rgb(0.180, 0.561, 0.518),
        dark: UIColor.systemTeal.resolvedColor(with: .darkAppearance)
    )

    /// Accent for diary milestone tags, named rather than repeated at each use.
    static let milestonePurple = adaptive(
        light: rgb(0.420, 0.247, 0.627),
        dark: rgb(0.7, 0.4, 0.9)
    )

    // MARK: Status

    /// Low-stock amber. System yellow is unreadable on a white card, so the
    /// light theme drops it to a dark amber.
    static let warningAmber = adaptive(
        light: rgb(0.541, 0.380, 0.0),
        dark: UIColor.systemYellow.resolvedColor(with: .darkAppearance)
    )

    /// The "after"/energy counterpart to the accent. System orange keeps its
    /// brightness in both schemes and drops to about 2:1 on a white card, so
    /// the light theme uses a deeper burnt orange.
    static let warmAccent = adaptive(
        light: rgb(0.761, 0.380, 0.039),
        dark: UIColor.systemOrange.resolvedColor(with: .darkAppearance)
    )

    /// Background and accent for the low-stock warning.
    static let warningBg = adaptive(
        light: rgb(0.984, 0.925, 0.918),
        dark: rgb(0.2, 0.05, 0.08)
    )

    /// Also the app's danger color: system red sits at 3.6:1 on a white card and
    /// 2.9:1 inside its own tinted badge, so "MISSED" and the delete action use
    /// this instead. The dark value is lifted slightly from the original
    /// (0.9, 0.4, 0.4) to clear AA inside that badge.
    static let warningAccent = adaptive(
        light: rgb(0.753, 0.224, 0.169),
        dark: rgb(0.922, 0.451, 0.439)
    )

    // MARK: Effects

    /// Drop shadow under a modal. A shadow tuned for a dark background reads as
    /// dirt on a light one, so the light theme uses a far softer one.
    static let appShadow = adaptive(
        light: UIColor.black.withAlphaComponent(0.14),
        dark: UIColor.black.withAlphaComponent(0.6)
    )

    /// Corner tint of the splash gradient.
    static let splashTint = adaptive(
        light: rgb(0.843, 0.910, 0.878),
        dark: rgb(0.05, 0.25, 0.22)
    )

    // MARK: Hero card

    /// The hero card carries its own gradient per time of day, and its label is
    /// white in both themes. So the light variants are not lighter — they are
    /// muted and *deeper* than the dark theme's pastels, which is what keeps
    /// white text readable on them and keeps the card from glaring against the
    /// cream background.

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

    /// Evening: plum moving into poppy. The sweep passes through a plum-rose
    /// rather than muddying, and the poppy end is muted enough to hold white
    /// text — a brighter one would drop the label below the contrast floor.
    static let heroEveningStart = adaptive(
        light: rgb(0.431, 0.353, 0.651),
        dark: UIColor.systemPurple.resolvedColor(with: .darkAppearance)
    )
    static let heroEveningEnd = adaptive(
        light: rgb(0.780, 0.267, 0.180),
        dark: UIColor.systemIndigo.resolvedColor(with: .darkAppearance)
    )
}
