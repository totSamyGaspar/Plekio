//
//  DiaryReminderSettings.swift
//  PillFlow
//

import Foundation

/// The daily diary reminder's two settings, in one place.
///
/// Both the Settings screen (through `@AppStorage`) and `NotificationService`
/// read them: the service has to re-arm the reminder after a course reschedule
/// wipes the pending queue, and it cannot ask the UI for the values.
///
/// The time is stored as minutes since midnight rather than a `Date`.
/// `@AppStorage` has no Date overload, and a date carries a day with it — which
/// is meaningless for a reminder that only ever needs an hour and a minute.
enum DiaryReminderSettings {

    static let enabledKey = "diaryReminderEnabled"
    static let minuteOfDayKey = "diaryReminderMinuteOfDay"

    /// 21:00. Late enough that the day is over, early enough not to land after
    /// the user is asleep.
    static let defaultMinuteOfDay = 21 * 60

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Falls back to the default when nothing was ever written: `integer(forKey:)`
    /// answers 0 for a missing key, which would mean midnight.
    static var minuteOfDay: Int {
        let stored = UserDefaults.standard.object(forKey: minuteOfDayKey) as? Int
        return stored ?? defaultMinuteOfDay
    }

    static func hourAndMinute(from minuteOfDay: Int) -> (hour: Int, minute: Int) {
        let clamped = min(max(minuteOfDay, 0), 24 * 60 - 1)
        return (clamped / 60, clamped % 60)
    }
}
