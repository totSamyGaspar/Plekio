//
//  DoseUndoCenter.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class DoseUndoCenter {

    // MARK: - Properties

    /// Nil once the undo window has closed.
    private(set) var current: UndoableDoseAction?

    @ObservationIgnored private let doseLogging: DoseLoggingUseCaseProtocol
    @ObservationIgnored private let errors: any ErrorReporting
    @ObservationIgnored private let time: any TimeSource

    /// Kept so a newer offer cancels the older countdown instead of racing it.
    @ObservationIgnored private var expiryTask: Task<Void, Never>?

    init(doseLogging: DoseLoggingUseCaseProtocol, errors: any ErrorReporting, time: any TimeSource) {
        self.doseLogging = doseLogging
        self.errors = errors
        self.time = time
    }

    // MARK: - Actions

    /// Opens the undo window; does nothing when `undo` is nil (nothing was written).
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

    /// Runs the inverse and closes the window. Returns whether anything was written.
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
