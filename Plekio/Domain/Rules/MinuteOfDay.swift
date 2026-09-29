//
//  MinuteOfDay.swift
//  Plekio
//
//  Created by Edward Gasparian on 29.09.2026.
//

import Foundation

/// A wall-clock time as minutes past midnight (480 is 08:00). Stored without a
/// date or time zone, so 08:00 stays 08:00 after the user changes time zone.
nonisolated enum MinuteOfDay {

    static func clamp(_ minuteOfDay: Int) -> Int {
        min(max(minuteOfDay, 0), 24 * 60 - 1)
    }

    static func hourAndMinute(_ minuteOfDay: Int) -> (hour: Int, minute: Int) {
        let clamped = clamp(minuteOfDay)
        return (clamped / 60, clamped % 60)
    }

    /// The wall-clock time of `date` in `calendar`'s time zone.
    static func of(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
