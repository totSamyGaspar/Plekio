//
//  DoseSchedule.swift
//  Plekio
//

import Foundation

/// The rules that decide when a medication is due, and what counts as the same
/// dose.
///
/// Two consumers read them: `fetchPills` builds a day's doses for the screen, the
/// notification planner builds the same occurrences for reminders. They must not
/// disagree — a dose the list shows and the queue omits appears on screen and
/// never rings — so the course window, the frequency step, the conversion from a
/// time of day to a date, and the definition of "the same dose" are stated here
/// once. Daylight saving is the change waiting to happen; when it comes, it comes
/// to one file.
///
/// Everything here is pure and takes its calendar, so tests can pin a timezone and
/// neither caller has to own the rule.
enum DoseSchedule {

    /// One occurrence of one medication on one day: the time of day it is due,
    /// and that time placed on the date.
    ///
    /// A named type rather than a tuple because callers read it by field and tests
    /// map over it — and key paths do not reach into tuples.
    struct Slot: Equatable {
        let hour: Int
        let minute: Int
        let date: Date
    }

    /// The fields that identify one occurrence: a day, plus a time of day.
    static let slotUnits: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]

    /// How long after its time a dose can still be answered before it counts as
    /// missed. Shared so the dashboard and an exported report never disagree
    /// about whether the same dose was missed.
    static let missedGrace: TimeInterval = 3600

    /// The canonical key for an occurrence.
    ///
    /// Two dates describing the same dose on the same day give the same key,
    /// whatever their seconds hold. This is the single answer to "is this the same
    /// dose", used for matching a log to a slot, for deciding whether a slot is
    /// settled, and for keying the schedule.
    static func slotKey(_ date: Date, calendar: Calendar) -> DateComponents {
        calendar.dateComponents(slotUnits, from: date)
    }

    /// Whether a course covers this day.
    ///
    /// All three must be start-of-day values. Both ends are inclusive: a course
    /// ending today still has today's doses.
    static func isActive(courseStartDay: Date, courseEndDay: Date, day: Date) -> Bool {
        day >= courseStartDay && day <= courseEndDay
    }

    /// Whether a medication is due on `day`, counting in `frequencyDays` steps from
    /// the course's first day.
    ///
    /// Both dates must be start-of-day values. The callers already hold them, and
    /// normalising here would add two calendar round-trips to the innermost loop of
    /// the schedule walk, which runs per medication per day of the horizon.
    ///
    /// A frequency of zero would make every day a dose day and put the medication
    /// at every slot. The picker only offers 1/2/3/7/14/30, but imported or
    /// migrated data has no such manners, so it is refused here rather than trusted
    /// at each call site. A day before the course starts is refused too: Swift's
    /// remainder keeps the sign of its left operand, so -3 % 3 is 0 and a negative
    /// elapsed count would otherwise read as a dose day.
    static func isDoseDay(frequencyDays: Int, courseStartDay: Date, day: Date, calendar: Calendar) -> Bool {
        guard frequencyDays > 0 else { return false }
        guard let elapsed = calendar.dateComponents([.day], from: courseStartDay, to: day).day else { return false }
        return elapsed >= 0 && elapsed.isMultiple(of: frequencyDays)
    }

    /// A medication's times of day reduced to (hour, minute), in the order set.
    ///
    /// `timesOfDay` holds whole dates whose day part is meaningless — only the time
    /// of day is real — so this is what makes that explicit instead of leaving each
    /// caller to remember it.
    static func timesOfDay(_ times: [Date], calendar: Calendar) -> [(hour: Int, minute: Int)] {
        times.map { time in
            let parts = calendar.dateComponents([.hour, .minute], from: time)
            return (parts.hour ?? 0, parts.minute ?? 0)
        }
    }

    /// A time of day placed on a given day.
    ///
    /// Nil when that combination does not exist on that date — the hour a
    /// spring-forward transition skips. Both callers currently drop such a dose;
    /// the point of routing them through here is that there is now one place to
    /// decide on something better.
    static func slotDate(hour: Int, minute: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    /// Every slot a medication has on `day`, given its course.
    ///
    /// The convenience for callers that walk one day at a time. The schedule
    /// rebuild does not use it: it walks a horizon and hoists the per-medication
    /// work out of the loop, so it composes the primitives above itself.
    static func slots(
        for medication: MedicationItem,
        courseStartDay: Date,
        courseEndDay: Date,
        on day: Date,
        calendar: Calendar
    ) -> [Slot] {
        guard isActive(courseStartDay: courseStartDay, courseEndDay: courseEndDay, day: day),
              isDoseDay(
                frequencyDays: medication.frequencyDays,
                courseStartDay: courseStartDay,
                day: day,
                calendar: calendar
              )
        else { return [] }

        return timesOfDay(medication.timesOfDay, calendar: calendar).compactMap { time in
            slotDate(hour: time.hour, minute: time.minute, on: day, calendar: calendar)
                .map { Slot(hour: time.hour, minute: time.minute, date: $0) }
        }
    }

    /// The slots a medication's logs have already answered for — taken, or
    /// deliberately skipped. Both mean "do not ring for this one".
    static func settledSlots(of medication: MedicationItem, calendar: Calendar) -> Set<DateComponents> {
        Set(
            medication.logs
                .filter { $0.isTaken || $0.skippedAt != nil }
                .map { slotKey($0.scheduledTime, calendar: calendar) }
        )
    }

    /// The medication's logs for one day, indexed by slot key.
    ///
    /// For callers that resolve every slot of a day: built once per medication,
    /// where matching each slot against the whole history separately would rescan
    /// every log for every slot. A months-long course has hundreds of logs and the
    /// weekly statistics ask for seven days in a row.
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

    /// The log recording one occurrence, if there is one.
    ///
    /// For callers that want a single slot of a single medication. Resolving a
    /// whole day this way is what `logsBySlot` is for.
    static func log(of medication: MedicationItem, at slot: Date, calendar: Calendar) -> DoseLog? {
        let key = slotKey(slot, calendar: calendar)
        return medication.logs.first { slotKey($0.scheduledTime, calendar: calendar) == key }
    }
}

extension DayPeriod {

    /// Which part of the day an hour belongs to.
    ///
    /// The boundaries lived as a nested ternary in the middle of the dose-building
    /// loop, which is the last place anyone would look for them.
    init(hour: Int) {
        switch hour {
        case ..<12: self = .morning
        case ..<17: self = .noon
        default:    self = .evening
        }
    }
}
