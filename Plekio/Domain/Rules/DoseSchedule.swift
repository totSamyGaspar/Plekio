//
//  DoseSchedule.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation

/// When a medication is due and what counts as the same dose. Shared by the
/// dose list and the notification planner so they never disagree; pure, calendar injected.
nonisolated enum DoseSchedule {

    // MARK: - Types

    /// One occurrence of one medication on one day.
    struct Slot: Equatable {
        let hour: Int
        let minute: Int
        let date: Date
    }

    // MARK: - Constants

    static let slotUnits: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]

    /// Seconds after its time before an unanswered dose counts as missed.
    /// Shared so the dashboard and exported report agree.
    static let missedGrace: TimeInterval = 3600

    // MARK: - Rules

    /// The canonical "same dose" key: equal for the same day, hour and minute, ignoring seconds.
    static func slotKey(_ date: Date, calendar: Calendar) -> DateComponents {
        calendar.dateComponents(slotUnits, from: date)
    }

    /// All arguments are start-of-day values; both ends are inclusive.
    static func isActive(courseStartDay: Date, courseEndDay: Date, day: Date) -> Bool {
        day >= courseStartDay && day <= courseEndDay
    }

    /// Dates must be start-of-day (not normalised here: hot loop). Rejects
    /// frequency <= 0 and days before the start (a negative multiple would match).
    static func isDoseDay(frequencyDays: Int, courseStartDay: Date, day: Date, calendar: Calendar) -> Bool {
        guard frequencyDays > 0 else { return false }
        guard let elapsed = calendar.dateComponents([.day], from: courseStartDay, to: day).day else { return false }
        return elapsed >= 0 && elapsed.isMultiple(of: frequencyDays)
    }

    /// Times of day as (hour, minute); the day part of `timesOfDay` is meaningless.
    static func timesOfDay(_ times: [Date], calendar: Calendar) -> [(hour: Int, minute: Int)] {
        times.map { time in
            let parts = calendar.dateComponents([.hour, .minute], from: time)
            return (parts.hour ?? 0, parts.minute ?? 0)
        }
    }

    /// Nil when the time does not exist that day (skipped by a DST transition).
    static func slotDate(hour: Int, minute: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// The times and frequency in force on `day` (start of day): the earliest
    /// revision still valid then, else the medication's current schedule.
    static func schedule(of medication: MedicationItem, on day: Date) -> (timesOfDay: [Date], frequencyDays: Int) {
        let revision = medication.scheduleRevisions
            .filter { $0.validUntil > day }
            .min { $0.validUntil < $1.validUntil }
        return revision.map { ($0.timesOfDay, $0.frequencyDays) }
            ?? (medication.timesOfDay, medication.frequencyDays)
    }

    /// Every slot a medication has on `day`, given its course.
    static func slots(
        for medication: MedicationItem,
        courseStartDay: Date,
        courseEndDay: Date,
        on day: Date,
        calendar: Calendar
    ) -> [Slot] {
        let schedule = schedule(of: medication, on: day)

        guard isActive(courseStartDay: courseStartDay, courseEndDay: courseEndDay, day: day),
              isDoseDay(
                frequencyDays: schedule.frequencyDays,
                courseStartDay: courseStartDay,
                day: day,
                calendar: calendar
              )
        else { return [] }

        return timesOfDay(schedule.timesOfDay, calendar: calendar).compactMap { time in
            slotDate(hour: time.hour, minute: time.minute, on: day, calendar: calendar)
                .map { Slot(hour: time.hour, minute: time.minute, date: $0) }
        }
    }

    // MARK: - Logs

    /// Slots already taken or deliberately skipped; neither should ring.
    static func settledSlots(of medication: MedicationItem, calendar: Calendar) -> Set<DateComponents> {
        Set(
            medication.logs
                .filter { $0.status.isSettled }
                .map { slotKey($0.scheduledTime, calendar: calendar) }
        )
    }

    /// The medication's logs for one day, indexed by slot key, to avoid rescanning per slot.
    static func logsBySlot(
        of medication: MedicationItem,
        on day: Date,
        calendar: Calendar
    ) -> [DateComponents: DoseLog] {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return [:] }

        return medication.logs.reduce(into: [:]) { result, log in
            guard log.scheduledTime >= day, log.scheduledTime < nextDay else { return }
            result[slotKey(log.scheduledTime, calendar: calendar)] = log
        }
    }

    /// The log for one occurrence; use `logsBySlot` for a whole day.
    static func log(of medication: MedicationItem, at slot: Date, calendar: Calendar) -> DoseLog? {
        let key = slotKey(slot, calendar: calendar)
        return medication.logs.first { slotKey($0.scheduledTime, calendar: calendar) == key }
    }
}

// MARK: - DayPeriod

nonisolated extension DayPeriod {

    /// Which part of the day an hour belongs to.
    init(hour: Int) {
        switch hour {
        case ..<12: self = .morning
        case ..<17: self = .noon
        default:    self = .evening
        }
    }
}
