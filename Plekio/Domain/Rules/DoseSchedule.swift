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

    /// Seconds after its time before an unanswered dose counts as missed.
    /// Shared so the dashboard and exported report agree.
    static let missedGrace: TimeInterval = 3600

    // MARK: - Rules

    /// Inclusive at both ends. Rejects frequency <= 0, which imported data can carry.
    static func isDoseDay(_ day: LocalDay, start: LocalDay, end: LocalDay, frequencyDays: Int) -> Bool {
        frequencyDays > 0 && start <= day && day <= end
            && start.days(to: day).isMultiple(of: frequencyDays)
    }

    /// A medication's schedule as of one day.
    struct Schedule: Equatable {
        let minutesOfDay: [Int]
        let frequencyDays: Int
        let dosage: Int
    }

    /// The schedule in force on `day`: the earliest revision still valid then, else
    /// the medication's current fields.
    static func schedule(of medication: MedicationItem, on day: LocalDay) -> Schedule {
        let revision = medication.scheduleRevisions
            .filter { $0.validUntilDay > day }
            .min { $0.validUntilDay < $1.validUntilDay }
        if let revision {
            return Schedule(minutesOfDay: revision.minutesOfDay, frequencyDays: revision.frequencyDays, dosage: revision.dosage)
        }
        return Schedule(minutesOfDay: medication.minutesOfDay, frequencyDays: medication.frequencyDays, dosage: medication.dosage)
    }

    /// The day's slots, with the course-date and schedule revisions in force then, worked out on local days: a course and its revisions keep
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

        guard isDoseDay(today, start: start, end: days.end, frequencyDays: schedule.frequencyDays)
        else { return [] }

        return schedule.minutesOfDay.compactMap { minuteOfDay in
            let time = MinuteOfDay.hourAndMinute(minuteOfDay)
            return LocalSlot(day: today, minuteOfDay: minuteOfDay).date(in: calendar)
                .map { Slot(hour: time.hour, minute: time.minute, date: $0) }
        }
    }

    // MARK: - Logs

    /// Slots already taken or deliberately skipped; neither should ring.
    /// - Parameter day: logs before it are left out. The reminder rebuild only plans
    ///   from today, and decoding a slot costs a calendar call per log of the whole history.
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

    /// The medication's logs for one day, indexed by slot, to avoid rescanning per slot.
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
