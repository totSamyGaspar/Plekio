//
//  AppTheme.swift
//  Plekio
//

import SwiftUI

//  Which theme is in force, and the modifiers that apply it.
//
//  Split out of a single 356-line Theme.swift: choosing a theme, naming the
//  colours, and configuring UIKit are three unrelated jobs that happened to
//  share a file, and only the first of them is about the user's preference.

// MARK: - Theme selection

/// The appearance the user picked in Settings.
///
/// Stored as a raw string in `UserDefaults` so `@AppStorage` can read it from
/// any view without an observable object in between: every screen that needs
/// the scheme reads the same key and re-renders on its own when it changes.
enum AppTheme: String, CaseIterable, Identifiable {
    /// Follows the iOS setting, which is what HIG asks an app to do by default.
    /// Listed first: `allCases` is what the picker in Settings renders.
    case system
    case light
    case dark

    /// One name for the defaults key, so a typo cannot split the setting in two.
    static let storageKey = "appTheme"

    var id: String { rawValue }

    /// `nil` hands the choice back to the system — `preferredColorScheme(nil)`
    /// stops overriding rather than picking a side.
    var colorScheme: ColorScheme? {
        // Explicit returns rather than a switch expression: mixing `nil` with
        // implicit member syntax leans on optional promotion that the shorthand
        // form does not always infer.
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var iconName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
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

    /// On `.system` there is nothing to override, so the scheme already in the
    /// environment is passed straight back through.
    @Environment(\.colorScheme) private var inheritedScheme

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, theme.colorScheme ?? inheritedScheme)
    }
}

extension View {
    func appTheme() -> some View { modifier(AppThemeModifier()) }
    func appColorScheme() -> some View { modifier(AppColorSchemeModifier()) }
}
