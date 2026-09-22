//
//  DailyReminder.swift
//  Plekio
//

import Foundation

/// A reminder that fires at the same time (or times) every day: what it says,
/// when it fires, and whether it is on at all.
///
/// There are two — the diary check-in and the blood-pressure measurement — and
/// they differ in wording, in how many times a day they may fire, and in the
/// keys they store under. Adding the second one as a copy of the first would
/// have been quicker and would have started them drifting immediately: a daily
/// reminder has to be re-armed after a course reschedule clears the pending
/// queue (see `NotificationService.removeAllPending`), and that is exactly the
/// kind of detail a copy forgets.
///
/// Times are stored as minutes since midnight rather than as `Date`s.
/// `@AppStorage` has no Date overload, and a date drags a day along with it —
/// meaningless for something that repeats every day.
enum DailyReminder: String, CaseIterable, Identifiable, Sendable {

    case diary
    case bloodPressure

    var id: String { rawValue }

    /// The key this reminder's kind travels under in a notification's userInfo,
    /// so AppDelegate knows which screen to open. The dose reminders are told
    /// apart by carrying `medicationIds`, which these deliberately do not.
    static let userInfoKey = "kind"

    // MARK: - Shape

    /// How many times a day this reminder may fire.
    ///
    /// Blood pressure is measured on a schedule — morning, midday, evening are
    /// the usual three — while a diary check-in is a summary of the day and
    /// happens once. The cap is also a notification budget: each time costs one
    /// of the 64 pending slots iOS allows, permanently.
    var maxTimes: Int {
        switch self {
        case .diary: return 1
        case .bloodPressure: return 3
        }
    }

    var defaultMinutesOfDay: [Int] {
        switch self {
        // Late enough that the day is over, early enough not to land after the
        // user is asleep.
        case .diary: return [21 * 60]
        // Morning, before breakfast — when a reading is most comparable with the
        // one taken the day before.
        case .bloodPressure: return [9 * 60]
        }
    }

    // MARK: - Stored settings

    /// Matches the key the diary reminder already writes under, so switching to
    /// this type does not silently reset anyone's existing reminder.
    var enabledKey: String { "\(rawValue)ReminderEnabled" }

    var timesKey: String { "\(rawValue)ReminderMinutesOfDay" }

    /// The single-time key the diary reminder shipped with. Still read, so an
    /// existing reminder keeps the time its owner picked instead of quietly
    /// jumping back to the default after an update.
    var legacyMinuteOfDayKey: String { "\(rawValue)ReminderMinuteOfDay" }

    /// Read by NotificationService as well as the Settings screen: the service
    /// re-arms the reminder after a schedule rebuild and cannot ask the UI.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    var minutesOfDay: [Int] {
        let defaults = UserDefaults.standard

        if let raw = defaults.string(forKey: timesKey) {
            let parsed = Self.minutes(fromRaw: raw, limit: maxTimes)
            if !parsed.isEmpty { return parsed }
        }

        if let legacy = defaults.object(forKey: legacyMinuteOfDayKey) as? Int {
            return [Self.clamp(legacy)]
        }

        return defaultMinutesOfDay
    }

    // MARK: - Times, stored as text

    /// A comma-separated list, because `@AppStorage` stores strings and not
    /// arrays. Parsing holds the two invariants that matter — every time inside
    /// the day, never more than the cap — so nothing downstream has to re-check.
    ///
    /// Deliberately not sorted or de-duplicated: the order is the order the user
    /// entered, and re-ordering on read would shuffle the rows under their
    /// finger the moment a dragged time passed its neighbour.
    /// `nonisolated`, along with the three helpers below: they are arithmetic on
    /// integers and strings, they belong to no actor, and `map(clamp)` passes one
    /// of them into a nonisolated closure — which the module's default main-actor
    /// isolation would otherwise make illegal.
    nonisolated static func minutes(fromRaw raw: String, limit: Int) -> [Int] {
        raw.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .map(clamp)
            .prefix(limit)
            .map { $0 }
    }

    nonisolated static func raw(from minutes: [Int]) -> String {
        minutes.map(String.init).joined(separator: ",")
    }

    nonisolated static func clamp(_ minuteOfDay: Int) -> Int {
        min(max(minuteOfDay, 0), 24 * 60 - 1)
    }

    nonisolated static func hourAndMinute(from minuteOfDay: Int) -> (hour: Int, minute: Int) {
        let clamped = clamp(minuteOfDay)
        return (clamped / 60, clamped % 60)
    }

    // MARK: - Notification identity

    /// Fixed identifiers, not UUIDs: arming the reminder replaces the previous
    /// requests instead of stacking copies at the old times.
    ///
    /// The first slot keeps the bare identifier the diary reminder already uses,
    /// so an update replaces what is in the queue rather than adding beside it.
    func requestIdentifier(at index: Int) -> String {
        let base: String
        switch self {
        case .diary: base = "DIARY_REMINDER"
        case .bloodPressure: base = "BLOOD_PRESSURE_REMINDER"
        }
        return index == 0 ? base : "\(base)_\(index)"
    }

    /// Every identifier this reminder could have taken, so cancelling clears the
    /// times it no longer uses as well as the ones it does.
    var allRequestIdentifiers: [String] {
        (0..<maxTimes).map(requestIdentifier(at:))
    }

    /// One category each. Neither carries actions today, but a shared category
    /// would mean any action added to one appears on the other.
    var categoryIdentifier: String {
        switch self {
        case .diary: return "DIARY_REMINDER_CATEGORY"
        case .bloodPressure: return "BLOOD_PRESSURE_REMINDER_CATEGORY"
        }
    }

    // MARK: - Wording

    var notificationTitle: String {
        switch self {
        case .diary:
            return NotificationText.localized("📔 Time for your check-in")
        case .bloodPressure:
            return NotificationText.localized("🩺 Time to measure your blood pressure")
        }
    }

    var notificationBody: String {
        switch self {
        case .diary:
            return NotificationText.localized("Log how you feel today: mood, energy and symptoms")
        case .bloodPressure:
            return NotificationText.localized("Take a reading and log it in your diary")
        }
    }

    var settingsTitle: LocalizedStringResource {
        switch self {
        case .diary: return "Diary reminder"
        case .bloodPressure: return "Blood pressure reminder"
        }
    }

    var settingsIcon: String {
        switch self {
        case .diary: return "text.book.closed.fill"
        case .bloodPressure: return "heart.text.square.fill"
        }
    }
}
