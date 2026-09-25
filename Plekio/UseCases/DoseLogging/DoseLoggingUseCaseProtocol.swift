//
//  DoseLoggingUseCaseProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - DoseLogOutcome

/// Result of a dose write (already done) plus the reminder rebuild it started.
struct DoseLogOutcome {

    /// Empty when every dose was already in the requested state.
    let written: [PillDose]

    /// Nil when nothing was written.
    let reminderSync: Task<Void, Never>?

    /// Inverse command for undo via `perform(_:)`; nil when nothing was written.
    var undo: DoseCommand? = nil

    var didWrite: Bool { !written.isEmpty }

    /// For notification actions: iOS may suspend the app once the response is
    /// reported handled, so wait for reminders first. Screens don't wait.
    func waitForReminders() async {
        await reminderSync?.value
    }

    static let nothing = DoseLogOutcome(written: [], reminderSync: nil)
}

// MARK: - DoseLoggingUseCaseProtocol

@MainActor
protocol DoseLoggingUseCaseProtocol {

    /// Untaken doses in a slot, matched within 1 s (slot arrives from `userInfo` as a Double).
    func openDoses(medicationIds: [UUID], at slot: Date) -> [PillDose]

    /// Flips one dose (dashboard checkbox).
    @discardableResult
    func toggle(_ dose: PillDose) throws -> DoseLogOutcome

    /// Logs as taken; already-taken doses are left alone (never toggles).
    @discardableResult
    func markTaken(_ doses: [PillDose]) throws -> DoseLogOutcome

    /// Records a deliberate skip. Doses already taken or skipped are left alone.
    @discardableResult
    func markSkipped(_ doses: [PillDose]) throws -> DoseLogOutcome

    /// Undoes "Log all"; doses unticked by hand since are not touched.
    @discardableResult
    func revertTaken(_ doses: [PillDose]) throws -> DoseLogOutcome

    /// Undoes a skip; doses taken since stay taken.
    @discardableResult
    func revertSkipped(_ doses: [PillDose]) throws -> DoseLogOutcome

    /// Runs any dose command; used for undo.
    @discardableResult
    func perform(_ command: DoseCommand) throws -> DoseLogOutcome
}
