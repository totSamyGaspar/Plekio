//
//  DoseSheetActions.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

@MainActor
final class DoseSheetActions {

    // MARK: - Properties

    private let doseLogging: any DoseLoggingUseCaseProtocol
    private let notifications: any NotificationServiceProtocol
    private let undo: DoseUndoCenter
    private let errors: any ErrorReporting

    // MARK: - Init

    init(doseLogging: any DoseLoggingUseCaseProtocol,
         notifications: any NotificationServiceProtocol,
         undo: DoseUndoCenter,
         errors: any ErrorReporting) {
        self.doseLogging = doseLogging
        self.notifications = notifications
        self.undo = undo
        self.errors = errors
    }

    // MARK: - Actions

    /// Logs pending doses and offers undo in the shared banner on Today.
    func take(_ doses: [PillDose]) {
        guard let outcome = errors.attempt({ try doseLogging.markTaken(doses) }) else { return }
        undo.offer(.logged, undo: outcome.undo)
    }

    /// Skips open doses; the undo banner is the only way to revert.
    func skip(_ doses: [PillDose]) {
        guard let outcome = errors.attempt({ try doseLogging.markSkipped(doses) }) else { return }
        undo.offer(.skipped, undo: outcome.undo)
    }

    /// Schedules a snooze reminder; nothing is written.
    @discardableResult
    func snooze(_ doses: [PillDose]) -> Task<Void, Never> {
        // One snooze per slot, each carrying its own dose time.
        let bySlot = Dictionary(grouping: doses, by: \.time)
        return Task { [notifications] in
            for (slot, group) in bySlot {
                await notifications.scheduleSnooze(
                    for: group.map(\.medicationId.uuidString),
                    names: group.map(\.name),
                    slot: slot
                )
            }
        }
    }
}
