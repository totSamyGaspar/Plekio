//
//  SettingsStore.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - SettingsKey

/// Every UserDefaults key the app writes. The strings are storage: changing one
/// silently resets that setting for every user.
nonisolated enum SettingsKey {
    static let appLockEnabled = "appLockEnabled"
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let hasCompletedTour = "hasCompletedTour"
    static let appTheme = "appTheme"
    static let userProfile = "userProfile"
    static let refillReminderEnabled = "refillReminderEnabled"
    static let refillReminderMinuteOfDay = "refillReminderMinuteOfDay"
    static let reviewActiveDays = "reviewActiveDays"
    static let reviewLastActiveDay = "reviewLastActiveDay"
    static let reviewRequestedVersion = "reviewRequestedVersion"
    // Per-reminder keys ("<reminder>ReminderEnabled", ...) live in DailyReminder.
}

// MARK: - SettingsStore

@MainActor
final class SettingsStore {

    // MARK: - Properties

    /// Passed to `.defaultAppStorage(_:)` so `@AppStorage` reads the same domain.
    let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Onboarding

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: SettingsKey.hasSeenOnboarding) }
        set { defaults.set(newValue, forKey: SettingsKey.hasSeenOnboarding) }
    }

    /// The first-run tour was finished or skipped; it never shows again.
    var hasCompletedTour: Bool {
        get { defaults.bool(forKey: SettingsKey.hasCompletedTour) }
        set { defaults.set(newValue, forKey: SettingsKey.hasCompletedTour) }
    }

    var isAppLockEnabled: Bool {
        get { defaults.bool(forKey: SettingsKey.appLockEnabled) }
        set { defaults.set(newValue, forKey: SettingsKey.appLockEnabled) }
    }

    // MARK: - Profile

    /// Who the report is for; the non-view access path (views use `@AppStorage`).
    var userProfile: UserProfile {
        get { UserProfile.current(in: defaults) }
        set { defaults.set(StoredProfile(newValue).rawValue, forKey: SettingsKey.userProfile) }
    }

    // MARK: - Refill reminder

    /// On unless switched off: running out of a medication is worth a nudge by default.
    var isRefillReminderEnabled: Bool {
        defaults.object(forKey: SettingsKey.refillReminderEnabled) as? Bool ?? true
    }

    var refillReminderMinuteOfDay: Int {
        guard let stored = defaults.object(forKey: SettingsKey.refillReminderMinuteOfDay) as? Int else {
            return RefillReminder.defaultMinuteOfDay
        }
        return MinuteOfDay.clamp(stored)
    }

    // MARK: - Daily reminders

    func isEnabled(_ reminder: DailyReminder) -> Bool {
        defaults.bool(forKey: reminder.enabledKey)
    }

    /// Fire times in minutes past midnight: stored list, else legacy single time, else default.
    func minutesOfDay(for reminder: DailyReminder) -> [Int] {
        if let raw = defaults.string(forKey: reminder.timesKey) {
            let parsed = DailyReminder.minutes(fromRaw: raw, limit: reminder.maxTimes)
            if !parsed.isEmpty { return parsed }
        }

        if let legacy = defaults.object(forKey: reminder.legacyMinuteOfDayKey) as? Int {
            return [MinuteOfDay.clamp(legacy)]
        }

        return reminder.defaultMinutesOfDay
    }
}
