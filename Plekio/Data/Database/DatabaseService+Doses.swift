//
//  DatabaseService+Doses.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import OSLog
import SwiftData

/// Dose logging. When a dose is due is decided by `DoseSchedule`, shared with
/// the notification planner so screen and reminders agree.
extension DatabaseService: DoseStoring {

    // MARK: - Fetch

    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]? = nil) -> [PillDose] {
        let calendar = time.calendar
        let targetDate = calendar.startOfDay(for: date)

        if let cachedPills = persistence.cachedPills(for: targetDate) {
            return cachedPills
        }

        let courses: [TreatmentCourse]
        if let preFetched = preFetchedCourses {
            courses = preFetched
        } else {
            let descriptor = FetchDescriptor<TreatmentCourse>()
            courses = fetch(descriptor)
        }

        let sortedPills = DoseDay.pills(of: courses, on: targetDate, calendar: calendar)

        persistence.cachePills(sortedPills, for: targetDate)
        return sortedPills
    }

    /// One course fetch for the whole range, not one per day.
    func fetchPills(onDays days: [Date]) -> [Date: [PillDose]] {
        let calendar = time.calendar
        let courses = fetch(FetchDescriptor<TreatmentCourse>())

        var result: [Date: [PillDose]] = [:]
        for day in days {
            result[calendar.startOfDay(for: day)] = fetchPills(for: day, preFetchedCourses: courses)
        }
        return result
    }

    /// Reads on DoseHistoryReader's context. Sees only committed data, which is
    /// all there is: every write goes through `commit`.
    func pillHistory(onDays days: [Date]) async -> [Date: [PillDose]] {
        let calendar = time.calendar
        let reader = await persistence.doseHistoryReader()
        do {
            let result = try await reader.pills(onDays: days, calendar: calendar)
            persistence.readSucceeded()
            return result
        } catch {
            persistence.reportReadFailure(error)
            return [:]
        }
    }

    // MARK: - Lookup

    private func fetchMedication(id medicationId: UUID) -> MedicationItem? {
        let descriptor = FetchDescriptor<MedicationItem>(
            predicate: #Predicate { $0.id == medicationId }
        )
        return fetch(descriptor).first
    }

    // MARK: - Bulk Logging

    /// Logs every still-open dose of one slot as taken in one commit.
    /// Not a toggle: doses already taken must stay taken.
    func markDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = time.calendar
        let takenAt = time.now
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

        // No commit when nothing changed: it would reset the cache and wake subscribers.
        guard changed else { return }
        try persistence.commit([.doses])
    }

    /// Reverses `markDosesTaken` for one slot; only ever un-logs taken doses.
    func unmarkDosesTaken(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = time.calendar
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

    /// Records a deliberate skip (not a missed dose) for one slot in one commit.
    /// Stock is untouched, and taken doses are left alone.
    func skipDoses(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = time.calendar
        let skippedAt = time.now

        for medicationId in ids {
            guard let med = fetchMedication(id: medicationId) else { continue }
            let existing = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar)

            guard let skipped = (existing?.status ?? .pending).skipping(at: skippedAt) else { continue }
            write(skipped, to: existing, of: med, at: scheduledTime)
        }

        try persistence.commit([.doses])
    }

    /// Reverses `skipDoses` for one slot; doses taken meanwhile are left as they are.
    func unskipDoses(medicationIds: [UUID], scheduledTime: Date) throws {
        let ids = Array(Set(medicationIds))
        guard !ids.isEmpty else { return }

        let calendar = time.calendar
        var changed = false

        for medicationId in ids {
            guard let med = fetchMedication(id: medicationId),
                  let log = DoseSchedule.log(of: med, at: scheduledTime, calendar: calendar),
                  let pending = log.status.unskipping()
            else { continue }

            log.status = pending
            changed = true
        }

        guard changed else { return }
        try persistence.commit([.doses])
    }

    // MARK: - Toggle

    /// Flips one dose: taken becomes pending, anything else becomes taken.
    func togglePill(medicationId: UUID, scheduledTime: Date) throws {
        guard let med = fetchMedication(id: medicationId) else { return }

        let existing = DoseSchedule.log(of: med, at: scheduledTime, calendar: time.calendar)
        let current = existing?.status ?? .pending

        if let reverted = current.reverting() {
            med.stockCount += Self.credit(reverted.credit, dosage: med.dosage)
            existing?.status = reverted.status
        } else {
            let quantity = Self.dispensed(med.dosage, from: med.stockCount)
            // Always applies: `reverting` failed, so the dose is not taken.
            guard let taken = current.taking(at: time.now, dispensed: quantity) else { return }
            med.stockCount -= quantity
            write(taken, to: existing, of: med, at: scheduledTime)
        }
        try persistence.commit([.doses])
    }

    // MARK: - Helpers

    /// Updates the slot's log, or creates it if the slot has none yet.
    private func write(_ status: DoseStatus, to existing: DoseLog?, of med: MedicationItem, at scheduledTime: Date) {
        if let existing {
            existing.status = status
        } else {
            med.logs.append(DoseLog(scheduledTime: scheduledTime, status: status))
        }
    }

    /// Units actually taken from stock; clamped so stock never goes negative.
    /// The result is recorded so undo credits back exactly the same amount.
    private static func dispensed(_ dosage: Int, from stock: Int) -> Int {
        max(0, min(dosage, stock))
    }

    /// Stock returned on un-logging: the recorded amount, else the dosage for older logs.
    private static func credit(_ recorded: Int?, dosage: Int) -> Int {
        recorded ?? dosage
    }
}
