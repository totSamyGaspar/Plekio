//
//  RefillReminder.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Foundation

/// One daily reminder listing every medication that is running low.
/// Re-planned on every rebuild, so it stops once stock is refilled or the course ends.
nonisolated enum RefillReminder {

    // MARK: - Constants

    static let identifier = "REFILL_REMINDER"

    /// Marks the request in `userInfo`, so a tap can be told apart from dose reminders.
    static let userInfoKey = "refillReminder"

    /// 10:00, in minutes past midnight, until the user picks another time.
    static let defaultMinuteOfDay = 10 * 60

    // MARK: - Plan

    struct Plan: Equatable {
        let medicationNames: [String]
        let fireDate: Date
    }

    /// Next `minuteOfDay` after `now`, listing what is low; nil when nothing is.
    static func plan(
        activeCourses: [TreatmentCourse],
        minuteOfDay: Int,
        now: Date,
        calendar: Calendar
    ) -> Plan? {
        let names = activeCourses
            .flatMap(\.medications)
            .filter(\.isLowOnStock)
            .map(\.name)
            .sorted()
        guard !names.isEmpty,
              let fireDate = calendar.nextDate(
                after: now,
                matching: DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60),
                matchingPolicy: .nextTime
              )
        else { return nil }

        return Plan(medicationNames: names, fireDate: fireDate)
    }
}
