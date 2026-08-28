//
//  Theme.swift
//  PillFlow
//
//  Created by Edward Gasparian on 11.06.2026.
//

import SwiftUI
import UIKit

// MARK: - Theme selection

/// The appearance the user picked in Settings.
///
/// Stored as a raw string in `UserDefaults` so `@AppStorage` can read it from
/// any view without an observable object in between: every screen that needs
/// the scheme reads the same key and re-renders on its own when it changes.
enum AppTheme: String, CaseIterable, Identifiable {
    case dark
    case light

    /// One name for the defaults key, so a typo cannot split the setting in two.
    static let storageKey = "appTheme"

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var iconName: String {
        switch self {
        case .dark: "moon.stars.fill"
        case .light: "sun.max.fill"
        }
    }
}

// MARK: - Applying the theme

/// Forces the chosen scheme on a view tree. Needed on every root and on every
/// sheet: a modal is its own presentation, so it does not inherit
/// `preferredColorScheme` from the screen that presented it.
struct AppThemeModifier: ViewModifier {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .dark

    func body(content: Content) -> some View {
        content.preferredColorScheme(theme.colorScheme)
    }
}

/// Same choice pushed down as an environment value rather than a window
/// preference — for UIKit-backed controls (pickers, text editors) that read
/// `\.colorScheme` directly instead of following the window.
struct AppColorSchemeModifier: ViewModifier {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .dark

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, theme.colorScheme)
    }
}

extension View {
    func appTheme() -> some View { modifier(AppThemeModifier()) }
    func appColorScheme() -> some View { modifier(AppColorSchemeModifier()) }
}

// MARK: - Palette

/// Resolves against the trait collection, so one `Color` covers both themes and
/// every existing call site switches with the app instead of being duplicated
/// per scheme.
private func adaptive(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
    UIColor(red: red, green: green, blue: blue, alpha: 1)
}

private let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

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

    /// Text and icons drawn *on* the accent fill, where the contrast runs the
    /// other way: the dark theme's accent is a light mint, the light theme's is
    /// a deep teal.
    static let onAccent = adaptive(
        light: rgb(1.0, 1.0, 1.0),
        dark: rgb(0.06, 0.08, 0.12)
    )

    // MARK: Accent

    /// The primary accent. It used to be referenced under two names —
    /// `Color.neonMint` and plain `Color.mint` — mixed together, sometimes on
    /// adjacent lines, so changing the accent in one place no longer worked.
    /// `accentPrimary` is now the only name for it.
    ///
    /// The light theme darkens it: system mint on white sits far below the
    /// contrast floor for text and small icons.
    static let accentPrimary = Color(UIColor.appAccent)

    /// Companion to the accent for gradients (progress ring).
    static let accentSecondary = adaptive(
        light: rgb(0.180, 0.561, 0.518),
        dark: UIColor.systemTeal.resolvedColor(with: darkTraits)
    )

    /// Accent for diary milestone tags. The literal was duplicated in three files.
    static let milestonePurple = adaptive(
        light: rgb(0.420, 0.247, 0.627),
        dark: rgb(0.7, 0.4, 0.9)
    )

    // MARK: Status

    /// Low-stock amber. System yellow is unreadable on a white card, so the
    /// light theme drops it to a dark amber.
    static let warningAmber = adaptive(
        light: rgb(0.541, 0.380, 0.0),
        dark: UIColor.systemYellow.resolvedColor(with: darkTraits)
    )

    /// The "after"/energy counterpart to the accent. System orange keeps its
    /// brightness in both schemes and drops to about 2:1 on a white card, so
    /// the light theme uses a deeper burnt orange.
    static let warmAccent = adaptive(
        light: rgb(0.761, 0.380, 0.039),
        dark: UIColor.systemOrange.resolvedColor(with: darkTraits)
    )

    /// Background and accent for the low-stock warning.
    static let warningBg = adaptive(
        light: rgb(0.984, 0.925, 0.918),
        dark: rgb(0.2, 0.05, 0.08)
    )

    static let warningAccent = adaptive(
        light: rgb(0.753, 0.224, 0.169),
        dark: rgb(0.9, 0.4, 0.4)
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
        dark: UIColor.systemMint.resolvedColor(with: darkTraits)
    )
    static let heroMorningEnd = adaptive(
        light: rgb(0.325, 0.420, 0.224),
        dark: UIColor.systemTeal.resolvedColor(with: darkTraits)
    )

    /// Midday: amber moving into terracotta.
    static let heroNoonStart = adaptive(
        light: rgb(0.690, 0.478, 0.133),
        dark: UIColor.systemOrange.resolvedColor(with: darkTraits)
    )
    static let heroNoonEnd = adaptive(
        light: rgb(0.561, 0.318, 0.090),
        dark: UIColor.systemYellow.resolvedColor(with: darkTraits)
    )

    /// Evening: plum moving into poppy. The sweep passes through a plum-rose
    /// rather than muddying, and the poppy end is muted enough to hold white
    /// text — a brighter one would drop the label below the contrast floor.
    static let heroEveningStart = adaptive(
        light: rgb(0.431, 0.353, 0.651),
        dark: UIColor.systemPurple.resolvedColor(with: darkTraits)
    )
    static let heroEveningEnd = adaptive(
        light: rgb(0.780, 0.267, 0.180),
        dark: UIColor.systemIndigo.resolvedColor(with: darkTraits)
    )
}

// MARK: - UIKit twins

/// The tab bar is configured through `UITabBarAppearance`, which takes UIColor
/// and resolves it against its own trait collection. A `UIColor(Color)` bridge
/// would be flattened at configuration time — in `App.init`, before any window
/// exists — so these are built as dynamic UIColors from the start.
extension UIColor {

    static let appAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemMint.resolvedColor(with: darkTraits)
            : UIColor(red: 0.122, green: 0.478, blue: 0.396, alpha: 1)
    }

    /// Wash over the tab bar blur: darkens the bar in the dark theme, lifts it
    /// off the cream background in the light one.
    static let appTabBarWash = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.4)
            : UIColor.white.withAlphaComponent(0.55)
    }
}
