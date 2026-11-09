//
//  LocalDay.swift
//  Plekio
//
//  Created by Edward Gasparian on 09.11.2026.
//

import Foundation

/// A calendar day without a time zone: 10 June stays 10 June wherever the person is.
/// Courses, revisions and dose slots are planned in local days, so a trip doesn't
/// move them; `start(in:)` turns one into a moment in the time zone of the moment.
nonisolated struct LocalDay: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone. Always Gregorian: a
    /// Buddhist or Japanese year from the calendar shown must not reach the store.
    init(_ date: Date, in calendar: Calendar) {
        let parts = Self.gregorian(like: calendar).dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// When this day begins in `calendar`'s time zone: midnight, or the first moment
    /// after it where a clock change skips midnight.
    func start(in calendar: Calendar) -> Date {
        let local = Self.gregorian(like: calendar)
        // Noon exists on every day; midnight doesn't everywhere.
        let noon = local.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        return local.startOfDay(for: noon)
    }

    func adding(days: Int) -> LocalDay {
        LocalDay(stored: Self.utc.date(byAdding: .day, value: days, to: stored) ?? stored)
    }

    /// Calendar days from this day to `other`, negative when `other` is earlier.
    /// Counted on the days themselves, so a clock change in between doesn't matter.
    func days(to other: LocalDay) -> Int {
        Self.utc.dateComponents([.day], from: stored, to: other.stored).day ?? 0
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: - Storage

    /// How the store keeps it: this day's midnight in UTC. Not a moment; just a
    /// `Date` that sorts and filters in queries like the day it stands for.
    var stored: Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    init(stored: Date) {
        let parts = Self.utc.dateComponents([.year, .month, .day], from: stored)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    // MARK: - Calendars

    static let utc = gregorian(.gmt)

    static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// `calendar` itself when it's Gregorian, as it nearly always is: no new calendar per call.
    static func gregorian(like calendar: Calendar) -> Calendar {
        calendar.identifier == .gregorian ? calendar : gregorian(calendar.timeZone)
    }
}
