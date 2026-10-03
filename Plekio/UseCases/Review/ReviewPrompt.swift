//
//  ReviewPrompt.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.10.2026.
//

import Foundation

// MARK: - ReviewPrompt

/// Decides when to ask for an App Store rating: once the app has been opened on
/// three different days, and at most once per version. StoreKit has the last
/// word (three prompts a year, none if the user turned them off), so this only
/// keeps us from asking too early or too often.
@MainActor
final class ReviewPrompt {

    // MARK: - Properties

    static let requiredActiveDays = 3

    private let defaults: UserDefaults
    private let time: any TimeSource
    private let appVersion: String

    /// Different days the app was opened on, counted since install.
    var activeDays: Int { defaults.integer(forKey: SettingsKey.reviewActiveDays) }

    // MARK: - Init

    init(defaults: UserDefaults, time: any TimeSource, appVersion: String = AppBrand.marketingVersion) {
        self.defaults = defaults
        self.time = time
        self.appVersion = appVersion
    }

    // MARK: - Recording

    /// Counts today once, however often the app comes to the front.
    func recordActiveDay() {
        let today = time.calendar.startOfDay(for: time.now)
        if let last = defaults.object(forKey: SettingsKey.reviewLastActiveDay) as? Date,
           time.calendar.isDate(last, inSameDayAs: today) {
            return
        }
        defaults.set(activeDays + 1, forKey: SettingsKey.reviewActiveDays)
        defaults.set(today, forKey: SettingsKey.reviewLastActiveDay)
    }

    // MARK: - Asking

    /// True at most once per version, once enough days are in; the caller then
    /// asks StoreKit. Spent on the first true, whether or not the system shows anything.
    func takeRequestIfDue() -> Bool {
        guard activeDays >= Self.requiredActiveDays,
              defaults.string(forKey: SettingsKey.reviewRequestedVersion) != appVersion
        else { return false }

        defaults.set(appVersion, forKey: SettingsKey.reviewRequestedVersion)
        return true
    }
}
