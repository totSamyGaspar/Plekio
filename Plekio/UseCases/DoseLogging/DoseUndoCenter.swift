//
//  DoseUndoCenter.swift
//  Plekio
//
//  The one undo window for dose actions, wherever they were taken.
//
//  It used to live inside DashboardViewModel, so only actions taken on the
//  dashboard could be undone. "Take" or "Skip" in the modal a notification
//  opens — presented by MainTabView, not the dashboard — had no way back, even
//  though the user lands on the dashboard right after and would look for the
//  banner there. Now both write into this, and the dashboard's banner reads it.
//
//  Owned by AppDependencies: one window for the app, so a newer action always
//  replaces an older offer, whichever screen made it.
//

import Foundation
import Observation

@Observable
@MainActor
final class DoseUndoCenter {

    /// The action that can still be taken back, while the window is open.
    private(set) var current: UndoableDoseAction?

    @ObservationIgnored private let doseLogging: DoseLoggingUseCaseProtocol
    @ObservationIgnored private let errors: any ErrorReporting
    @ObservationIgnored private let time: any TimeSource

    /// Closes the window on its own. Held so a newer offer replaces the older
    /// countdown instead of racing it.
    @ObservationIgnored private var expiryTask: Task<Void, Never>?

    init(doseLogging: DoseLoggingUseCaseProtocol, errors: any ErrorReporting, time: any TimeSource) {
        self.doseLogging = doseLogging
        self.errors = errors
        self.time = time
    }

    /// Opens the window for an action just taken. `undo` is the inverse the use
    /// case handed back; nil means nothing was written, so there is nothing to
    /// offer.
    func offer(_ kind: UndoableDoseAction.Kind, undo: DoseCommand?) {
        guard let undo else { return }
        expiryTask?.cancel()
        current = UndoableDoseAction(kind: kind, undo: undo, startedAt: time.now)

        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(UndoableDoseAction.window))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    /// Runs the inverse and closes the window. Returns whether anything was
    /// written, so the screen that asked can refresh.
    @discardableResult
    func undo() -> Bool {
        guard let action = current else { return false }
        dismiss()
        return errors.attempt({ try doseLogging.perform(action.undo) })?.didWrite ?? false
    }

    func dismiss() {
        expiryTask?.cancel()
        expiryTask = nil
        current = nil
    }
}
