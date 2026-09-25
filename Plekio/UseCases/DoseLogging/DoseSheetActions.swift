//
//  DoseSheetActions.swift
//  Plekio
//
//  What the three buttons of the take-sheet (TakePillModalView) do.
//
//  The sheet used to be presented from two places, each wiring the buttons
//  itself: DashboardView through its view model, MainTabView (a tapped
//  reminder) straight through the use case and the undo centre. "Snooze" was
//  written out in both views, calling the notification service directly. Two
//  copies of one behaviour drift; now both open the same route and the sheet's
//  buttons come here.
//

import Foundation

@MainActor
final class DoseSheetActions {

    private let doseLogging: any DoseLoggingUseCaseProtocol
    private let notifications: any NotificationServiceProtocol
    private let undo: DoseUndoCenter
    private let errors: any ErrorReporting

    init(doseLogging: any DoseLoggingUseCaseProtocol,
         notifications: any NotificationServiceProtocol,
         undo: DoseUndoCenter,
         errors: any ErrorReporting) {
        self.doseLogging = doseLogging
        self.notifications = notifications
        self.undo = undo
        self.errors = errors
    }

    /// Logs what of `doses` is still pending and offers it back in the shared
    /// undo banner — the user lands on Today, where the banner shows.
    func take(_ doses: [PillDose]) {
        guard let outcome = errors.attempt({ try doseLogging.markTaken(doses) }) else { return }
        undo.offer(.logged, undo: outcome.undo)
    }

    /// Skips what is still open. The banner is the only way back from a skip.
    func skip(_ doses: [PillDose]) {
        guard let outcome = errors.attempt({ try doseLogging.markSkipped(doses) }) else { return }
        undo.offer(.skipped, undo: outcome.undo)
    }

    /// Asks again in a while. Nothing is written: the dose stays open.
    @discardableResult
    func snooze(_ doses: [PillDose]) -> Task<Void, Never> {
        let ids = doses.map(\.medicationId.uuidString)
        let names = doses.map(\.name)
        return Task { [notifications] in
            await notifications.scheduleSnooze(for: ids, names: names)
        }
    }
}
