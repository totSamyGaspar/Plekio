//
//  LocalSlot.swift
//  Plekio
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Foundation

/// A dose time on a local day: 10 June at 08:00, wherever the person is. Dose logs
/// are keyed by it, so a dose taken at home still matches its slot abroad.
nonisolated struct LocalSlot: Hashable, Comparable, Sendable {
    let day: LocalDay
    /// Minutes past local midnight, see `MinuteOfDay`.
    let minuteOfDay: Int

    init(day: LocalDay, minuteOfDay: Int) {
        self.day = day
        self.minuteOfDay = minuteOfDay
    }

    /// The local day and time of `date` in `calendar`'s time zone.
    init(_ date: Date, in calendar: Calendar) {
        self.init(
            day: LocalDay(date, in: calendar),
            minuteOfDay: MinuteOfDay.of(date, calendar: LocalDay.gregorian(like: calendar))
        )
    }

    /// The moment in `calendar`'s time zone. Where a clock change skips the time,
    /// the next one that exists, as `DoseSchedule.slotDate` has always done.
    func date(in calendar: Calendar) -> Date? {
        let (hour, minute) = MinuteOfDay.hourAndMinute(minuteOfDay)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.start(in: calendar))
    }

    static func < (lhs: LocalSlot, rhs: LocalSlot) -> Bool {
        (lhs.day, lhs.minuteOfDay) < (rhs.day, rhs.minuteOfDay)
    }

    // MARK: - Storage

    /// How the store keeps it: the day and time as if in UTC. Not a moment.
    var stored: Date {
        day.stored.addingTimeInterval(TimeInterval(minuteOfDay * 60))
    }

    init(stored: Date) {
        let day = LocalDay(stored: stored)
        self.init(day: day, minuteOfDay: Int(stored.timeIntervalSince(day.stored) / 60))
    }
}
