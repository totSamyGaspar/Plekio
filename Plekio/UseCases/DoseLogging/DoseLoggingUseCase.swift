//
//  DoseLoggingUseCase.swift
//  Plekio
//
//  Before this type the same steps — write the dose, rebuild the reminder
//  queue, take the banner off the lock screen — were assembled by hand in
//  DashboardViewModel, PendingDose, AppDelegate and MainTabView, each with its
//  own small variation. Now a caller says WHAT the user did; the order of the
//  side effects is decided here, once.
//
//  It does not know about the UI: failures are thrown, and showing them is the
//  caller's business (AppErrorPresenter).
//

import Foundation

@MainActor
final class DoseLoggingUseCase: DoseLoggingUseCaseProtocol {

    private let dbService: any CourseStoring & DoseStoring
    private let notificationService: NotificationServiceProtocol

    init(dbService: any CourseStoring & DoseStoring, notificationService: NotificationServiceProtocol) {
        self.dbService = dbService
        self.notificationService = notificationService
    }

    // MARK: - Reading

    func openDoses(medicationIds: [UUID], at slot: Date) -> [PillDose] {
        scheduled(at: slot).filter { medicationIds.contains($0.medicationId) && !$0.isTaken }
    }

    // MARK: - Writing
    //
    // Every write is judged against what is stored when it runs, not against
    // the copies handed in — they may be stale (a screen that has not refreshed
    // yet) or recorded long ago (an undo). And every write hands back its
    // inverse, so undo is just the next command.

    func toggle(_ dose: PillDose) throws -> DoseLogOutcome {
        try dbService.togglePill(medicationId: dose.medicationId, scheduledTime: dose.time)

        // Un-logging opens the slot again: its reminder has to come back, and
        // there is nothing on the lock screen to clear.
        let nowTaken = !dose.isTaken
        return DoseLogOutcome(
            written: [dose],
            reminderSync: syncReminders(clearingSettledAt: nowTaken ? [dose.time] : []),
            undo: nowTaken ? .revertTake([dose]) : .take([dose])
        )
    }

    func markTaken(_ doses: [PillDose]) throws -> DoseLogOutcome {
        // Only "already taken" is filtered out. Being late is no reason to refuse:
        // a confirmation that crosses the missed threshold must still be logged.
        let pending = current(doses).filter { !$0.isTaken }
        guard !pending.isEmpty else { return .nothing }

        // One write per slot, not per dose: each is its own commit, cache reset
        // and change notification.
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
        // A taken dose is not skippable, and an already skipped one would only
        // have its timestamp moved.
        let open = current(doses).filter { !$0.isTaken && !$0.isSkipped }
        guard !open.isEmpty else { return .nothing }

        let bySlot = Dictionary(grouping: open, by: \.time)
        for (slot, group) in bySlot {
            try dbService.skipDoses(medicationIds: group.map(\.medicationId), scheduledTime: slot)
        }

        // A full rebuild rather than cancelling by medication: that would strip
        // every future reminder for it, not just this occurrence. The planner
        // treats a skipped slot like a taken one, so the rebuild leaves it out.
        return DoseLogOutcome(
            written: open,
            reminderSync: syncReminders(clearingSettledAt: Array(bySlot.keys)),
            undo: .revertSkip(open)
        )
    }

    func revertTaken(_ doses: [PillDose]) throws -> DoseLogOutcome {
        // Only doses still taken: the user may have unticked one by hand since,
        // and un-logging that one again would log it instead of undoing it.
        let toRevert = current(doses).filter(\.isTaken)
        guard !toRevert.isEmpty else { return .nothing }

        for (slot, group) in Dictionary(grouping: toRevert, by: \.time) {
            try dbService.unmarkDosesTaken(medicationIds: group.map(\.medicationId), scheduledTime: slot)
        }

        // Rebuilt so the reminders dropped by the original log come back —
        // that is the point of an undo. Nothing is settled, so nothing to clear.
        return DoseLogOutcome(
            written: toRevert,
            reminderSync: syncReminders(clearingSettledAt: []),
            undo: .take(toRevert)
        )
    }

    func revertSkipped(_ doses: [PillDose]) throws -> DoseLogOutcome {
        // Only doses still skipped: one taken since stays taken.
        let toRevert = current(doses).filter(\.isSkipped)
        guard !toRevert.isEmpty else { return .nothing }

        for (slot, group) in Dictionary(grouping: toRevert, by: \.time) {
            try dbService.unskipDoses(medicationIds: group.map(\.medicationId), scheduledTime: slot)
        }

        // The slot is unanswered again, so its reminder comes back.
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

    /// The stored state of `doses`, matched by id within their slots. A dose no
    /// longer on the schedule — its medication deleted — drops out.
    private func current(_ doses: [PillDose]) -> [PillDose] {
        let requested = Set(doses.map(\.id))
        return Set(doses.map(\.time))
            .flatMap { scheduled(at: $0) }
            .filter { requested.contains($0.id) }
    }

    // MARK: - Side effects

    /// Rebuilds the queue, then takes down delivered banners for slots that are
    /// now fully answered for. In one task, so the cleanup never races the
    /// rebuild. `NotificationService` chains overlapping rebuilds itself.
    private func syncReminders(clearingSettledAt slots: [Date]) -> Task<Void, Never> {
        Task { [notificationService, dbService] in
            await notificationService.rescheduleAll(using: dbService)

            for slot in slots {
                // Read back after the write: a banner may only come down once every
                // medication in it is answered for, and some may have been taken or
                // skipped earlier.
                let settled = Self.scheduled(in: dbService, at: slot)
                    .filter { $0.isTaken || $0.isSkipped }
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
