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
                            isTaken: log?.status.isTaken ?? false,
                            isSkipped: log?.status.isSkipped ?? false,
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
    /// un-logs the ones already ticked off. `DoseStatus.taking` refuses a dose
    /// already taken, and the slot costs one commit rather than one per dose.
    func markDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = Calendar.current
        let takenAt = Date()
        var changed = false

        for medicationId in ids {
            guard let med = fetchMedication(id: medicationId) else { continue }
            let existing = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar)

            let quantity = Self.dispensed(med.dosage, from: med.stockCount)
            guard let taken = (existing?.status ?? .pending).taking(at: takenAt, dispensed: quantity) else { continue }

            med.stockCount -= quantity
            write(taken, to: existing, of: med, at: scheduledTime)
            changed = true
        }

        // No commit when nothing moved: it would reset the cache and wake every
        // subscriber to announce that nothing happened.
        guard changed else { return }
        try persistence.commit([.doses])
    }

    /// Reverses `markDosesTaken` for one slot, in a single transaction.
    ///
    /// Only taken doses move, so an undo can only ever un-log — it cannot log
    /// something the user never did.
    func unmarkDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = Calendar.current
        var changed = false

        for medicationId in ids {
            guard let med = fetchMedication(id: medicationId),
                  let log = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar),
                  let reverted = log.status.reverting()
            else { continue }

            med.stockCount += Self.credit(reverted.credit, dosage: med.dosage)
            log.status = reverted.status
            changed = true
        }

        guard changed else { return }
        try persistence.commit([.doses])
    }

    // MARK: - Skip

    /// Records a deliberate skip for every medication in one slot, in a single
    /// transaction.
    ///
    /// Separate from `togglePill` because a skip is not "not taken" — see
    /// DoseStatus.skipped. Stock is untouched: nothing left the bottle. Doses
    /// already taken are left alone — `DoseStatus.skipping` refuses them, the
    /// same rule as bulk logging: a bulk action never reverses what it finds.
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
            let existing = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar)

            guard let skipped = (existing?.status ?? .pending).skipping(at: skippedAt) else { continue }
            write(skipped, to: existing, of: med, at: scheduledTime)
        }

        try persistence.commit([.doses])
    }

    // MARK: - Toggle take

    /// Flips one dose: taken becomes pending, anything else becomes taken.
    func togglePill(medicationId: UUID, scheduledTime: Date) throws {
        guard let med = fetchMedication(id: medicationId) else { return }

        let existing = DoseSchedule.log(of: med, at: scheduledTime, calendar: Calendar.current)
        let current = existing?.status ?? .pending

        if let reverted = current.reverting() {
            med.stockCount += Self.credit(reverted.credit, dosage: med.dosage)
            existing?.status = reverted.status
        } else {
            let quantity = Self.dispensed(med.dosage, from: med.stockCount)
            // Always applies: `reverting` failed, so the dose is not taken.
            guard let taken = current.taking(at: Date(), dispensed: quantity) else { return }
            med.stockCount -= quantity
            write(taken, to: existing, of: med, at: scheduledTime)
        }
        try persistence.commit([.doses])
    }

    // MARK: - Helpers

    /// Updates the slot's log, or creates it: a slot nobody has answered for yet
    /// has no log at all.
    private func write(_ status: DoseStatus, to existing: DoseLog?, of med: MedicationItem, at scheduledTime: Date) {
        if let existing {
            existing.status = status
        } else {
            med.logs.append(DoseLog(scheduledTime: scheduledTime, status: status))
        }
    }

    /// How many units a dose of `dosage` can actually take out of `stock`.
    ///
    /// Stock never goes negative and never yields more than it holds, so this is
    /// the one place the clamp lives — and its result is what gets recorded, so
    /// the credit on undo can be its exact mirror.
    private static func dispensed(_ dosage: Int, from stock: Int) -> Int {
        max(0, min(dosage, stock))
    }

    /// What goes back into the stock on un-logging: exactly what went out. A log
    /// from before that was recorded has only the dosage to go by — and only
    /// those logs fall back to it.
    private static func credit(_ recorded: Int?, dosage: Int) -> Int {
        recorded ?? dosage
    }
}
