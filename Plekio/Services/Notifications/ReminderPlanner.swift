//
//  ReminderPlanner.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import OSLog
import UserNotifications

/// Pure decisions about the notification queue; never touches the notification centre.
enum ReminderPlanner {

    // MARK: - Limits

    /// Requests the dose schedule may occupy: iOS caps pending at 64, and daily reminders
    /// (up to four), the refill reminder and snoozes need headroom. `nonisolated`: used as a default argument.
    nonisolated static let maxScheduled = 55

    /// Hard stop for the day walk, so a rare frequency or corrupt end date cannot spin.
    nonisolated static let maxHorizonDays = 365

    // MARK: - MedicationPlan

    /// One medication flattened once per rebuild, so the day walk never touches
    /// SwiftData relationships or rescans `logs`.
    private struct MedicationPlan {
        let courseName: String
        let medication: MedicationItem
        let startDay: Date
        let endDay: Date
        let frequencyDays: Int
        let times: [(hour: Int, minute: Int)]
        /// Slots already taken or skipped, keyed like trigger dates.
        let settledSlots: Set<DateComponents>
    }

    // MARK: - Schedule Building

    /// Slots to schedule: meds sharing a time are grouped, taken/skipped slots are left out,
    /// and the horizon runs as far as `slotBudget` allows (nothing re-plans while the app is closed).
    static func buildScheduleMap(
        activeCourses: [TreatmentCourse],
        now: Date,
        calendar: Calendar,
        slotBudget: Int = maxScheduled,
        horizonLimitInDays: Int = maxHorizonDays
    ) -> [Date: [(courseName: String, medication: MedicationItem)]] {

        let today = calendar.startOfDay(for: now)

        let plans: [MedicationPlan] = activeCourses.flatMap { course in
            course.medications.compactMap { med -> MedicationPlan? in
                // Guard against zero frequency from migrated or imported data.
                guard med.frequencyDays > 0 else { return nil }

                return MedicationPlan(
                    courseName: course.name,
                    medication: med,
                    startDay: DoseSchedule.startDay(
                        of: med,
                        courseStartDay: calendar.startOfDay(for: course.startDate),
                        calendar: calendar
                    ),
                    endDay: calendar.startOfDay(for: course.endDate),
                    frequencyDays: med.frequencyDays,
                    times: DoseSchedule.timesOfDay(med.timesOfDay, calendar: calendar),
                    // Skipped counts as settled, or the rebuild would bring it back.
                    settledSlots: DoseSchedule.settledSlots(of: med, calendar: calendar)
                )
            }
        }

        guard !plans.isEmpty else { return [:] }

        var scheduleMap: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

        // Walk day by day: the budget is spent in whole days.
        for dayOffset in 0..<horizonLimitInDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { break }

            // Every course is over; nothing further out can match.
            if plans.allSatisfy({ $0.endDay < day }) { break }

            var slotsForDay: [Date: [(courseName: String, medication: MedicationItem)]] = [:]

            for plan in plans {
                // Same DoseSchedule rules as the on-screen day list.
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

            // Whole days only, except a first day that alone exceeds the budget.
            if !scheduleMap.isEmpty, scheduleMap.count + slotsForDay.count > slotBudget { break }

            scheduleMap.merge(slotsForDay) { current, _ in current }

            if scheduleMap.count >= slotBudget { break }
        }

        return scheduleMap
    }

    // MARK: - Cancellation

    /// A group reminder rebuilt without one of its medications.
    struct RegroupedReminder {
        let identifier: String
        let medicationIds: [String]
        let medicationNames: [String]
        let triggerDate: Date
        let trigger: UNNotificationTrigger
    }

    /// Queue changes that stop reminders for one medication.
    struct CancellationPlan {
        let deliveredToRemove: [String]
        let pendingToRemove: [String]
        /// Re-added after the removals above, under the same identifiers.
        let regrouped: [RegroupedReminder]

        var isEmpty: Bool {
            deliveredToRemove.isEmpty && pendingToRemove.isEmpty && regrouped.isEmpty
        }
    }

    /// Delivered reminders are removed only if they name this medication alone;
    /// pending group reminders are rebuilt without it so the others still fire.
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

            // Older requests lack names, so they can only be removed, not rebuilt.
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
                    // Reused as is; a snooze interval trigger restarts its countdown.
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

    // MARK: - Snoozes

    /// Pending snoozes to keep across a rebuild: those with at least one dose still
    /// unanswered. Medications no longer in an active course don't count.
    static func snoozesToKeep(
        pending: [ReminderSnapshot],
        activeCourses: [TreatmentCourse],
        calendar: Calendar
    ) -> Set<String> {
        let medications = Dictionary(
            activeCourses.flatMap(\.medications).map { ($0.id.uuidString, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return Set(pending.compactMap { reminder in
            guard ReminderRequestFactory.isSnooze(reminder.identifier),
                  let slotTime = reminder.slotTime else { return nil }
            let slot = Date(timeIntervalSince1970: slotTime)

            let stillOpen = reminder.medicationIds.contains { id in
                guard let medication = medications[id] else { return false }
                let status = DoseSchedule.log(of: medication, at: slot, calendar: calendar)?.status ?? .pending
                return !status.isSettled
            }
            return stillOpen ? reminder.identifier : nil
        })
    }

    // MARK: - Delivered Cleanup

    /// Delivered reminders for `slot` whose medications are all settled; partly open groups stay.
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
