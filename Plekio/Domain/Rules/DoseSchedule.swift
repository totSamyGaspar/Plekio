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

    /// Nil when the time does not exist that day (skipped by a DST transition).
    static func slotDate(hour: Int, minute: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// A medication's schedule as of one day.
    struct Schedule: Equatable {
        let minutesOfDay: [Int]
        let frequencyDays: Int
        let dosage: Int
    }

    /// The schedule in force on `day` (start of day): the earliest revision still
    /// valid then, else the medication's current fields.
    /// The schedule in force on `day`, in the device's time zone; for the report.
    static func schedule(of medication: MedicationItem, on day: Date) -> Schedule {
        schedule(of: medication, on: LocalDay(day, in: .autoupdatingCurrent))
    }

    static func schedule(of medication: MedicationItem, on day: LocalDay) -> Schedule {
        let revision = medication.scheduleRevisions
            .filter { $0.validUntilDay > day }
            .min { $0.validUntilDay < $1.validUntilDay }
        if let revision {
            return Schedule(minutesOfDay: revision.minutesOfDay, frequencyDays: revision.frequencyDays, dosage: revision.dosage)
        }
        return Schedule(minutesOfDay: medication.minutesOfDay, frequencyDays: medication.frequencyDays, dosage: medication.dosage)
    }

    /// The first day a medication is taken: its own start when added mid-course,
    /// else the course start. Also the anchor for "every N days".
    static func startDay(of medication: MedicationItem, courseStartDay: Date, calendar: Calendar) -> Date {
        guard let own = medication.startDate else { return courseStartDay }
        return max(courseStartDay, calendar.startOfDay(for: own))
    }

    /// Resolves both course-date and medication revisions for the requested day.
    /// The day's slots, worked out on local days: a course and its revisions keep
    /// their days wherever `calendar`'s time zone is. `day` is a start of day in it.
    static func slots(
        for medication: MedicationItem,
        in course: TreatmentCourse,
        on day: Date,
        calendar: Calendar
    ) -> [Slot] {
        let today = LocalDay(day, in: calendar)
        let days = CourseRules.days(of: course, on: today)
        let start = medication.startDay.map { max(days.start, $0) } ?? days.start
        let schedule = schedule(of: medication, on: today)

        guard start <= today, today <= days.end,
              schedule.frequencyDays > 0,
              start.days(to: today).isMultiple(of: schedule.frequencyDays)
        else { return [] }

        return schedule.minutesOfDay.compactMap { minuteOfDay in
            let time = MinuteOfDay.hourAndMinute(minuteOfDay)
            return LocalSlot(day: today, minuteOfDay: minuteOfDay).date(in: calendar)
                .map { Slot(hour: time.hour, minute: time.minute, date: $0) }
        }
    }

    /// Every slot a medication has on `day`, given the course dates in force then.
    static func slots(
        for medication: MedicationItem,
        courseStartDay: Date,
        courseEndDay: Date,
        on day: Date,
        calendar: Calendar
    ) -> [Slot] {
        let schedule = schedule(of: medication, on: day)
        let start = startDay(of: medication, courseStartDay: courseStartDay, calendar: calendar)

        guard isActive(courseStartDay: start, courseEndDay: courseEndDay, day: day),
              isDoseDay(
                frequencyDays: schedule.frequencyDays,
                courseStartDay: start,
                day: day,
                calendar: calendar
              )
        else { return [] }

        return schedule.minutesOfDay.map(MinuteOfDay.hourAndMinute).compactMap { time in
            slotDate(hour: time.hour, minute: time.minute, on: day, calendar: calendar)
                .map { Slot(hour: time.hour, minute: time.minute, date: $0) }
        }
    }

    // MARK: - Logs

    /// Slots already taken or deliberately skipped; neither should ring.
    /// - Parameter day: logs before it are left out. The reminder rebuild only plans
    ///   from today, and a slot key costs a calendar call per log of the whole history.
    static func settledSlots(of medication: MedicationItem, from day: Date? = nil, calendar: Calendar) -> Set<LocalSlot> {
        // Stored forms compare like the slots they stand for, without decoding each log.
        let from = day.map { LocalDay($0, in: calendar).stored }
        return Set(
            medication.logs
                .filter { log in from.map { log.storedSlot >= $0 } ?? true }
                .filter { $0.status.isSettled }
                .map(\.slot)
        )
    }

    /// The medication's logs for one day, indexed by slot key, to avoid rescanning per slot.
    static func logsBySlot(
        of medication: MedicationItem,
        on day: Date,
        calendar: Calendar
    ) -> [LocalSlot: DoseLog] {
        let localDay = LocalDay(day, in: calendar)
        let (start, end) = (localDay.stored, localDay.adding(days: 1).stored)

        return medication.logs.reduce(into: [:]) { result, log in
            guard log.storedSlot >= start, log.storedSlot < end else { return }
            result[log.slot] = log
        }
    }

    /// The log for one occurrence; use `logsBySlot` for a whole day.
    static func log(of medication: MedicationItem, at slot: Date, calendar: Calendar) -> DoseLog? {
        let key = LocalSlot(slot, in: calendar).stored
        return medication.logs.first { $0.storedSlot == key }
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
