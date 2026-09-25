//
//  DatabaseService+Doses.swift
//  Plekio
//

import Foundation
import OSLog
import SwiftData

/// The dose log: what is due today, and what the user has answered for.
///
/// The rules about WHEN a dose is due are not here — they are in `DoseSchedule`,
/// shared with the notification planner so the screen and the reminders cannot
/// disagree.
extension DatabaseService: DoseStoring {

    // MARK: - Fetch

    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)

        if let cachedPills = persistence.cachedPills(for: targetDate) {
            return cachedPills
        }

        let courses: [TreatmentCourse]
        if let preFetched = preFetchedCourses {
            courses = preFetched
        } else {
            let descriptor = FetchDescriptor<TreatmentCourse>()
            courses = (try? context.fetch(descriptor)) ?? []
        }

        var dailyPills: [PillDose] = []

        // The window, the frequency step and the time-of-day arithmetic come from
        // DoseSchedule — the same source the notification rebuild reads, so the
        // screen and the reminders cannot disagree about a day.
        for course in courses {
            let courseStart = calendar.startOfDay(for: course.startDate)
            let courseEnd = calendar.startOfDay(for: course.endDate)

            for med in course.medications {
                let slots = DoseSchedule.slots(
                    for: med,
                    courseStartDay: courseStart,
                    courseEndDay: courseEnd,
                    on: targetDate,
                    calendar: calendar
                )
                guard !slots.isEmpty else { continue }

                let logsBySlot = DoseSchedule.logsBySlot(of: med, on: targetDate, calendar: calendar)

                for slot in slots {
                    let log = logsBySlot[DoseSchedule.slotKey(slot.date, calendar: calendar)]

                    dailyPills.append(
                        PillDose(
                            medicationId: med.id,
                            name: med.name,
                            dosage: med.dosage,
                            formSystemImage: med.formSystemImage,
                            time: slot.date,
                            period: DayPeriod(hour: slot.hour),
                            isTaken: log?.isTaken ?? false,
                            isSkipped: log?.skippedAt != nil,
                            stockCount: med.stockCount,
                            lowStockThreshold: med.lowStockThreshold
                        )
                    )
                }
            }
        }

        let sortedPills = dailyPills.sorted(by: { $0.time < $1.time })

        persistence.cachePills(sortedPills, for: targetDate)
        return sortedPills
    }

    /// One course fetch for the whole range, not one per day.
    func fetchPills(onDays days: [Date]) -> [Date: [PillDose]] {
        let calendar = Calendar.current
        let courses = (try? context.fetch(FetchDescriptor<TreatmentCourse>())) ?? []

        var result: [Date: [PillDose]] = [:]
        for day in days {
            result[calendar.startOfDay(for: day)] = fetchPills(for: day, preFetchedCourses: courses)
        }
        return result
    }

    // MARK: - Dose slots

    /// The one way this service reaches a medication by id. Written out three
    /// times before, which is three chances for the predicate to drift.
    private func fetchMedication(id medicationId: UUID) -> MedicationItem? {
        let descriptor = FetchDescriptor<MedicationItem>(
            predicate: #Predicate { $0.id == medicationId }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - Bulk logging

    /// Logs every still-open dose of one slot as taken, in a single transaction.
    ///
    /// Deliberately not a toggle: over a list of doses in unknown states a toggle
    /// un-logs the ones already ticked off. A dose already logged is left where it
    /// is, and the slot costs one commit rather than one per dose.
    func markDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = Calendar.current
        let takenAt = Date()
        var changed = false

        for medicationId in ids {
            guard let med = fetchMedication(id: medicationId) else { continue }

            let existing = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar)
            if existing?.isTaken == true { continue }

            let taken = Self.dispensed(med.dosage, from: med.stockCount)
            med.stockCount -= taken

            if let existing {
                existing.isTaken = true
                existing.actualTakeTime = takenAt
                // Taking a dose overrides an earlier decision to skip it.
                existing.skippedAt = nil
                existing.dispensedQuantity = taken
            } else {
                let newLog = DoseLog(scheduledTime: scheduledTime, isTaken: true)
                newLog.actualTakeTime = takenAt
                newLog.dispensedQuantity = taken
                med.logs.append(newLog)
            }
            changed = true
        }

        // No commit when nothing moved: it would reset the cache and wake every
        // subscriber to announce that nothing happened.
        guard changed else { return }
        try persistence.commit([.doses])
    }

    /// Reverses `markDosesTaken` for one slot, in a single transaction.
    ///
    /// Doses that are not logged as taken are left alone, so an undo can only ever
    /// un-log — it cannot log something the user never did.
    func unmarkDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = Calendar.current
        var changed = false

        for medicationId in ids {
            guard let med = fetchMedication(id: medicationId),
                  let log = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar),
                  log.isTaken
            else { continue }

            // Exactly what was taken out — see DoseLog.dispensedQuantity.
            med.stockCount += log.dispensedQuantity ?? med.dosage
            log.isTaken = false
            log.actualTakeTime = nil
            log.dispensedQuantity = nil
            changed = true
        }

        guard changed else { return }
        try persistence.commit([.doses])
    }

    // MARK: - Skip

    /// Records a deliberate skip for every medication in one slot, in a single
    /// transaction.
    ///
    /// Separate from `togglePill` because a skip is not "not taken": the statistics
    /// have to tell a declined dose from a forgotten one, and the schedule rebuild
    /// has to leave a skipped slot out while an untaken one gets its reminder back.
    /// Stock is untouched — nothing left the bottle.
    ///
    /// Doses already logged as taken are left alone rather than being un-taken —
    /// same rule as `markDosesTaken`: a bulk action never reverses what it finds.
    func skipDoses(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = Calendar.current
        let skippedAt = Date()

        // Fetched one at a time rather than with one `ids.contains` query: a slot
        // holds a handful of medications, and the point of this method is a single
        // commit, not a single fetch.
        for medicationId in ids {
            guard let med = fetchMedication(id: medicationId) else { continue }

            if let existingLog = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar) {
                guard !existingLog.isTaken else { continue }
                existingLog.skippedAt = skippedAt
            } else {
                let newLog = DoseLog(scheduledTime: scheduledTime, isTaken: false)
                newLog.skippedAt = skippedAt
                med.logs.append(newLog)
            }
        }

        try persistence.commit([.doses])
    }

    // MARK: - Toggle take

    /// How many units a dose of `dosage` can actually take out of `stock`.
    ///
    /// Stock never goes negative and never yields more than it holds, so this is
    /// the one place the clamp lives — and its result is what gets recorded, so
    /// the credit on undo can be its exact mirror.
    private static func dispensed(_ dosage: Int, from stock: Int) -> Int {
        max(0, min(dosage, stock))
    }

    func togglePill(medicationId: UUID, scheduledTime: Date) throws {
        guard let med = fetchMedication(id: medicationId) else { return }

        let calendar = Calendar.current

        if let existingLog = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar) {
            existingLog.isTaken.toggle()
            existingLog.actualTakeTime = existingLog.isTaken ? Date() : nil
            if existingLog.isTaken {
                // Taking a dose overrides an earlier decision to skip it, so the
                // two states can never both be set on one log.
                existingLog.skippedAt = nil

                let taken = Self.dispensed(med.dosage, from: med.stockCount)
                med.stockCount -= taken
                existingLog.dispensedQuantity = taken
            } else {
                // Exactly what was taken out, not a full dose. A log from before
                // this field existed records nothing, and a full dose is the best
                // guess available for those — and only for those.
                med.stockCount += existingLog.dispensedQuantity ?? med.dosage
                existingLog.dispensedQuantity = nil
            }
        } else {
            // actualTakeTime records when the dose was actually logged, which is how
            // lateness is captured: for a back-dated dose it exceeds scheduledTime.
            let newLog = DoseLog(scheduledTime: scheduledTime, isTaken: true)
            newLog.actualTakeTime = Date()

            let taken = Self.dispensed(med.dosage, from: med.stockCount)
            med.stockCount -= taken
            newLog.dispensedQuantity = taken

            med.logs.append(newLog)
        }
        try persistence.commit([.doses])
    }
}
