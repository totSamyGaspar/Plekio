//
//  SettingsStore.swift
//  Plekio
//
//  The app's small settings — flags and preferences kept in UserDefaults — in
//  one place, with typed accessors and one registry of keys.
//
//  Views keep reading them through `@AppStorage`: that is how SwiftUI makes a
//  setting reactive, and wrapping it would only add ceremony. What changes is
//  where they read from — the root sets `.defaultAppStorage(settings.defaults)`,
//  so `@AppStorage` and this store always look at the same UserDefaults.
//
//  Code that is not a view — the notification service re-arming daily
//  reminders, onboarding marking itself done — goes through this store instead
//  of `UserDefaults.standard`. That global was a hidden dependency: tests of the
//  reminders had to save and restore the real app's settings around every case.
//  Now a test hands in a store over its own suite.
//

import Foundation

/// Every UserDefaults key the app writes, so two settings cannot collide and a
/// key cannot be misspelled at one of the places that uses it. The daily
/// reminders' keys are per reminder — see `DailyReminder.enabledKey` and
/// friends — and are listed here only by prefix.
///
/// The strings are storage: changing one silently resets that setting for
/// everyone who has it.
nonisolated enum SettingsKey {
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let appTheme = "appTheme"
    static let userProfile = "userProfile"
    // "<reminder>ReminderEnabled", "<reminder>ReminderMinutesOfDay",
    // "<reminder>ReminderMinuteOfDay" (legacy) — see DailyReminder.
}

@MainActor
final class SettingsStore {

    /// Exposed for `.defaultAppStorage(_:)` at the root, so `@AppStorage` in the
    /// views reads the same domain as this store.
    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Onboarding

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: SettingsKey.hasSeenOnboarding) }
        set { defaults.set(newValue, forKey: SettingsKey.hasSeenOnboarding) }
    }

    // MARK: - Daily reminders

    /// Read by NotificationService as well as the Settings screen: the service
    /// re-arms the reminder after a schedule rebuild and cannot ask the UI.
    func isEnabled(_ reminder: DailyReminder) -> Bool {
        defaults.bool(forKey: reminder.enabledKey)
    }

    /// The times the reminder fires at, as minutes past midnight: the stored
    /// list if there is one, else the single time an older version stored, else
    /// the reminder's default.
    func minutesOfDay(for reminder: DailyReminder) -> [Int] {
        if let raw = defaults.string(forKey: reminder.timesKey) {
            let parsed = DailyReminder.minutes(fromRaw: raw, limit: reminder.maxTimes)
            if !parsed.isEmpty { return parsed }
        }

        if let legacy = defaults.object(forKey: reminder.legacyMinuteOfDayKey) as? Int {
            return [DailyReminder.clamp(legacy)]
        }

        return reminder.defaultMinutesOfDay
    }
}
