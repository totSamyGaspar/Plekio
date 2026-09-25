//
//  DoseLoggingUseCase.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

@MainActor
final class DoseLoggingUseCase: DoseLoggingUseCaseProtocol {

    // MARK: - Properties

    private let dbService: any CourseStoring & DoseStoring
    private let notificationService: NotificationServiceProtocol

    // MARK: - Init

    init(dbService: any CourseStoring & DoseStoring, notificationService: NotificationServiceProtocol) {
        self.dbService = dbService
        self.notificationService = notificationService
    }

    // MARK: - Reading

    func openDoses(medicationIds: [UUID], at slot: Date) -> [PillDose] {
        scheduled(at: slot).filter { medicationIds.contains($0.medicationId) && !$0.isTaken }
    }

    // MARK: - Writing

    // Writes use stored state, not the passed-in copies (may be stale or from an undo).

    func toggle(_ dose: PillDose) throws -> DoseLogOutcome {
        try dbService.togglePill(medicationId: dose.medicationId, scheduledTime: dose.time)

        // Un-logging reopens the slot: reminder returns, nothing to clear.
        let nowTaken = !dose.isTaken
        return DoseLogOutcome(
            written: [dose],
            reminderSync: syncReminders(clearingSettledAt: nowTaken ? [dose.time] : []),
            undo: nowTaken ? .revertTake([dose]) : .take([dose])
        )
    }

    func markTaken(_ doses: [PillDose]) throws -> DoseLogOutcome {
        // Late confirmations (past the missed threshold) must still be logged.
        let pending = current(doses).filter { !$0.isTaken }
        guard !pending.isEmpty else { return .nothing }

        // One write per slot, not per dose: each write is a commit and change notification.
        let bySlot = Dictionary(grouping: pending, by: \.time)
        for (slot, group) in bySlot {
            try dbService.markDosesTaken(medicationIds: group.map(\.medicationId), scheduledTime: slot)
        }

        return DoseLogOutcome(
            written: pending,
            reminderSync: syncReminders(clearingSettledAt: Array(bySlot.keys)),
            undo: .revertTake(pending)
        )
    }

    func markSkipped(_ doses: [PillDose]) throws -> DoseLogOutcome {
        // Only pending doses: taken ones can't be skipped, skipped ones would get a new timestamp.
        let open = current(doses).filter { $0.status == .pending }
        guard !open.isEmpty else { return .nothing }

        let bySlot = Dictionary(grouping: open, by: \.time)
        for (slot, group) in bySlot {
            try dbService.skipDoses(medicationIds: group.map(\.medicationId), scheduledTime: slot)
        }

        // Full rebuild: cancelling by medication would drop all its future reminders.
        return DoseLogOutcome(
            written: open,
            reminderSync: syncReminders(clearingSettledAt: Array(bySlot.keys)),
            undo: .revertSkip(open)
        )
    }

    func revertTaken(_ doses: [PillDose]) throws -> DoseLogOutcome {
        // Only still-taken doses; one unticked by hand since must not be touched.
        let toRevert = current(doses).filter(\.isTaken)
        guard !toRevert.isEmpty else { return .nothing }

        for (slot, group) in Dictionary(grouping: toRevert, by: \.time) {
            try dbService.unmarkDosesTaken(medicationIds: group.map(\.medicationId), scheduledTime: slot)
        }

        // Rebuild restores the reminders the original log removed.
        return DoseLogOutcome(
            written: toRevert,
            reminderSync: syncReminders(clearingSettledAt: []),
            undo: .take(toRevert)
        )
    }

    func revertSkipped(_ doses: [PillDose]) throws -> DoseLogOutcome {
        // Only still-skipped doses; one taken since stays taken.
        let toRevert = current(doses).filter(\.isSkipped)
        guard !toRevert.isEmpty else { return .nothing }

        for (slot, group) in Dictionary(grouping: toRevert, by: \.time) {
            try dbService.unskipDoses(medicationIds: group.map(\.medicationId), scheduledTime: slot)
        }

        return DoseLogOutcome(
            written: toRevert,
            reminderSync: syncReminders(clearingSettledAt: []),
            undo: .skip(toRevert)
        )
    }

    func perform(_ command: DoseCommand) throws -> DoseLogOutcome {
        switch command {
        case .take(let doses): return try markTaken(doses)
        case .skip(let doses): return try markSkipped(doses)
        case .revertTake(let doses): return try revertTaken(doses)
        case .revertSkip(let doses): return try revertSkipped(doses)
        }
    }

    /// Stored state of `doses`; doses whose medication was deleted drop out.
    private func current(_ doses: [PillDose]) -> [PillDose] {
        let requested = Set(doses.map(\.id))
        return Set(doses.map(\.time))
            .flatMap { scheduled(at: $0) }
            .filter { requested.contains($0.id) }
    }

    // MARK: - Side effects

    /// Rebuilds reminders, then clears delivered banners for settled slots.
    /// One task so the cleanup can't race the rebuild.
    private func syncReminders(clearingSettledAt slots: [Date]) -> Task<Void, Never> {
        Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)

            for slot in slots {
                // Re-read after the write: only settled medications' banners may be cleared.
                let settled = Self.scheduled(in: dbService, at: slot)
                    .filter(\.status.isSettled)
                    .map(\.medicationId)
                guard !settled.isEmpty else { continue }
                await notificationService.clearDelivered(settledMedicationIds: settled, scheduledTime: slot)
            }
        }
    }

    private func scheduled(at slot: Date) -> [PillDose] {
        Self.scheduled(in: dbService, at: slot)
    }

    private static func scheduled(in dbService: any CourseStoring & DoseStoring, at slot: Date) -> [PillDose] {
        dbService.fetchPills(for: slot, preFetchedCourses: nil)
            .filter { abs($0.time.timeIntervalSince(slot)) < 1 }
    }
}
