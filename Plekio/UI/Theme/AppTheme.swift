//
//  AppTheme.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI

// MARK: - AppTheme

/// The appearance picked in Settings, stored as a raw string for `@AppStorage`.
enum AppTheme: String, CaseIterable, Identifiable {
    /// Follows iOS. Keep first: `allCases` order is the Settings picker order.
    case system
    case light
    case dark

    static let storageKey = SettingsKey.appTheme

    var id: String { rawValue }

    /// Nil for `.system`: no override.
    var colorScheme: ColorScheme? {
        // Explicit returns: a switch expression mixing `nil` and `.light` doesn't always infer.
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

// MARK: - Modifiers

/// Applies the chosen scheme. Needed on every root and sheet: modals don't
/// inherit `preferredColorScheme`.
struct AppThemeModifier: ViewModifier {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    func body(content: Content) -> some View {
        content.preferredColorScheme(theme.colorScheme)
    }
}

/// Sets `\.colorScheme` in the environment, for UIKit-backed controls that read it directly.
struct AppColorSchemeModifier: ViewModifier {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    /// Passed through unchanged on `.system`.
    @Environment(\.colorScheme) private var inheritedScheme

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, theme.colorScheme ?? inheritedScheme)
    }
}

// MARK: - View + Theme

extension View {
    func appTheme() -> some View { modifier(AppThemeModifier()) }
    func appColorScheme() -> some View { modifier(AppColorSchemeModifier()) }
}
