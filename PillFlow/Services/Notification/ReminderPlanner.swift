//
//  ReminderPlanner.swift
//  PillFlow
//

import Foundation
import OSLog
import UserNotifications

/// Every decision about the notification queue, and nothing that touches it.
///
/// Pulled out of NotificationService so these rules can be tested. They are the
/// part that has actually gone wrong — a skip that cancelled a whole course, a
/// group reminder rebuilt without the medication that was still due — and until
/// now they could only run against the real notification centre, whose reads
/// return values that cannot be constructed in a test.
///
/// The service above this composes: read the queue, ask for a plan, carry it out.
enum ReminderPlanner {

    /// How many requests the dose schedule may occupy.
    ///
    /// iOS keeps at most 64 pending local notifications per app and silently drops
    /// the rest, and the dose schedule is not the only thing in that queue: the
    /// daily reminders hold one slot per time, permanently — up to four between
    /// them — and a snooze takes one per group. The horizon below now stretches
    /// until this budget is spent, so the ceiling is reached in normal use rather
    /// than in theory: the headroom has to be real.
    ///
    /// `nonisolated` because it is a default argument of `buildScheduleMap`, and a
    /// default argument is evaluated at the call site — outside this type's
    /// main-actor isolation. Safe: an immutable Int carries no state to race over.
    nonisolated static let maxScheduled = 56

    /// Hard stop for the day-by-day walk, so a course with a very rare frequency
    /// (or a corrupt end date) cannot spin. Reached only when the budget never
    /// fills up. `nonisolated` for the same reason as the budget above.
    nonisolated static let maxHorizonDays = 365

    /// One medication flattened into everything the day walk needs.
    ///
    /// Prepared once per rebuild so the walk never touches a SwiftData
    /// relationship or rescans `logs` for each day it considers. That rescan was
    /// affordable while the horizon was three days; over weeks it is the
    /// difference between hundreds of comparisons and hundreds of thousands.
    private struct MedicationPlan {
        let courseName: String
        let medication: MedicationItem
        let startDay: Date
        let endDay: Date
        let frequencyDays: Int
        let times: [(hour: Int, minute: Int)]
        /// Slots the user has already answered for — taken or deliberately
        /// skipped — keyed the way a trigger date is keyed.
        let settledSlots: Set<DateComponents>
    }

    // MARK: - Schedule Building

    /// Pure, side-effect-free computation of what needs to be scheduled, kept
    /// separate from scheduleNotifications so its rules can be unit tested without
    /// a real notification centre. `now`/`calendar` default to live values so
    /// production behaviour is unaffected; tests inject fixed ones.
    ///
    /// Three rules live here. Medications that share a trigger time are grouped
    /// into a single push. Slots the user has already answered for — logged as
    /// taken, or deliberately skipped — produce nothing, so a dose logged in
    /// advance doesn't still ring and a skipped one doesn't come back. And the
    /// horizon runs as far ahead as `slotBudget` allows rather than a fixed few
    /// days: nothing re-plans the schedule while the app is closed, so a short
    /// window means the course goes quiet on the first day the user doesn't open
    /// it — the one failure this app cannot afford.
    static func buildScheduleMap(
        activeCourses: [TreatmentCourse],
        now: Date = Date(),
        calendar: Calendar = .current,
        slotBudget: Int = maxScheduled,
        horizonLimitInDays: Int = maxHorizonDays
    ) -> [Date: [(courseName: String, medication: MedicationItem)]] {

        let today = calendar.startOfDay(for: now)

        let plans: [MedicationPlan] = activeCourses.flatMap { course in
            course.medications.compactMap { med -> MedicationPlan? in
                // The dose-day step is frequencyDays. At zero every day would match
                // and the medication would be scheduled at every slot. Unreachable
                // from the UI (the picker offers 1/2/3/7/14/30), but data can arrive
                // from a migration or an import.
                guard med.frequencyDays > 0 else { return nil }

                return MedicationPlan(
                    courseName: course.name,
                    medication: med,
                    startDay: calendar.startOfDay(for: course.startDate),
                    endDay: calendar.startOfDay(for: course.endDate),
                    frequencyDays: med.frequencyDays,
                    times: DoseSchedule.timesOfDay(med.timesOfDay, calendar: calendar),
                    // Skipped counts alongside taken: without it the rebuild puts
                    // a skipped slot's reminder straight back.
                    settledSlots: DoseSchedule.settledSlots(of: med, calendar: calendar)
                )
            }
        }

        guard !plans.isEmpty else { return [:] }

        var scheduleMap: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

        // Driven by the day rather than by each medication's own stepping: a day is
        // the unit the budget is spent in, and asking "is this a dose day" with one
        // modulo replaces walking a course forward from a start date months back.
        for dayOffset in 0..<horizonLimitInDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { break }

            // Every course is over; nothing further out can match.
            if plans.allSatisfy({ $0.endDay < day }) { break }

            var slotsForDay: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

            for plan in plans {
                // The window and the frequency step come from DoseSchedule, the
                // same rules the day's list on screen is built from. Both were
                // written out here as well until they were one thing.
                guard DoseSchedule.isActive(
                    courseStartDay: plan.startDay, courseEndDay: plan.endDay, day: day
                ) else { continue }

                guard DoseSchedule.isDoseDay(
                    frequencyDays: plan.frequencyDays,
                    courseStartDay: plan.startDay,
                    day: day,
                    calendar: calendar
                ) else { continue }

                for time in plan.times {
                    guard let triggerDate = DoseSchedule.slotDate(
                        hour: time.hour, minute: time.minute, on: day, calendar: calendar
                    ), triggerDate > now else { continue }

                    let slot = DoseSchedule.slotKey(triggerDate, calendar: calendar)
                    guard !plan.settledSlots.contains(slot) else { continue }

                    slotsForDay[triggerDate, default: []].append(
                        (courseName: plan.courseName, medication: plan.medication)
                    )
                }
            }

            guard !slotsForDay.isEmpty else { continue }

            // Whole days only. Half a day inside the budget would give the user the
            // 08:00 reminder and not the 20:00 one, which reads as the app losing
            // doses rather than as a horizon. The exception is a first day that
            // fills the budget on its own — covering it partly still beats covering
            // nothing, and scheduleNotifications trims by time from there.
            if !scheduleMap.isEmpty, scheduleMap.count + slotsForDay.count > slotBudget { break }

            scheduleMap.merge(slotsForDay) { current, _ in current }

            if scheduleMap.count >= slotBudget { break }
        }

        return scheduleMap
    }

    // MARK: - Cancelling one medication

    /// A group reminder rebuilt without one of its medications.
    struct RegroupedReminder {
        let identifier: String
        let medicationIds: [String]
        let medicationNames: [String]
        let triggerDate: Date
        let trigger: UNNotificationTrigger
    }

    /// What has to happen to the queue for one medication to stop being reminded
    /// about — used when it is deleted, or its course is.
    struct CancellationPlan {
        let deliveredToRemove: [String]
        let pendingToRemove: [String]
        /// Re-added after the removals above, under the same identifiers.
        let regrouped: [RegroupedReminder]

        var isEmpty: Bool {
            deliveredToRemove.isEmpty && pendingToRemove.isEmpty && regrouped.isEmpty
        }
    }

    /// Works out that plan.
    ///
    /// Two rules, both of which have been wrong before.
    ///
    /// A delivered notification cannot be edited, only removed, so one is taken off
    /// the lock screen ONLY when it referred to this medication and nothing else.
    /// Removing any notification that merely mentioned the id took the reminder for
    /// the other medications in that slot down with it.
    ///
    /// A pending one is different: it can be replaced. A group reminder is rebuilt
    /// without this medication rather than dropped whole, so cancelling one
    /// medication never silences the others sharing its time.
    static func cancellationPlan(
        forMedication medicationId: UUID,
        pending: [ReminderSnapshot],
        delivered: [ReminderSnapshot]
    ) -> CancellationPlan {
        let targetId = medicationId.uuidString

        let deliveredToRemove = delivered
            .filter { $0.medicationIds == [targetId] }
            .map(\.identifier)

        var pendingToRemove: [String] = []
        var regrouped: [RegroupedReminder] = []

        for reminder in pending {
            guard reminder.medicationIds.contains(targetId) else { continue }
            pendingToRemove.append(reminder.identifier)

            // Names arrived later than ids: requests scheduled by an older version
            // do not carry them, so there is nothing to rebuild the text from and
            // the reminder can only be removed.
            guard reminder.medicationNames.count == reminder.medicationIds.count else { continue }

            let kept = zip(reminder.medicationIds, reminder.medicationNames)
                .filter { $0.0 != targetId }

            guard !kept.isEmpty,
                  let trigger = reminder.trigger,
                  let slotTime = reminder.slotTime
            else { continue }

            regrouped.append(
                RegroupedReminder(
                    identifier: reminder.identifier,
                    medicationIds: kept.map(\.0),
                    medicationNames: kept.map(\.1),
                    triggerDate: Date(timeIntervalSince1970: slotTime),
                    // The trigger is reused as is. For a calendar trigger that is
                    // exact; an interval (snooze) trigger restarts its countdown,
                    // which is acceptable for fifteen minutes.
                    trigger: trigger
                )
            )
        }

        return CancellationPlan(
            deliveredToRemove: deliveredToRemove,
            pendingToRemove: pendingToRemove,
            regrouped: regrouped
        )
    }

    // MARK: - Clearing the lock screen

    /// Which delivered reminders can come down now that these medications are
    /// settled for this slot.
    ///
    /// One notification can cover several medications at once — slots are grouped
    /// by time — so while any medication in a group is still unanswered the
    /// reminder is valid and stays. Only fully closed slots are cleared.
    static func deliveredToClear(
        settledMedicationIds: Set<String>,
        slot: Date,
        delivered: [ReminderSnapshot]
    ) -> [String] {
        guard !settledMedicationIds.isEmpty else { return [] }

        return delivered.compactMap { reminder in
            guard !reminder.medicationIds.isEmpty,
                  reminder.covers(slot: slot),
                  Set(reminder.medicationIds).isSubset(of: settledMedicationIds)
            else { return nil }
            return reminder.identifier
        }
    }
}
