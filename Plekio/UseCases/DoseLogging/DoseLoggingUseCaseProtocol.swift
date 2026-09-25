//
//  DoseLoggingUseCaseProtocol.swift
//  Plekio
//
//  Every way the user answers for a dose — the checkbox on the dashboard,
//  "Log all", "Skip", the undo banner, the buttons on a notification and the
//  sheet a notification opens — goes through this one boundary.
//

import Foundation

/// What a dose action actually changed, and a handle on the reminder work it
/// started.
///
/// The write is synchronous and already done when this comes back, so a screen
/// can refresh at once. The reminder rebuild runs behind it; `reminderSync`
/// is there for the one caller that must not return before it finishes.
struct DoseLogOutcome {

    /// The doses that were written. Empty means there was nothing to write —
    /// every dose was already in the requested state — and no reminder work was
    /// started.
    let written: [PillDose]

    /// The rebuild started by the write. Nil when nothing was written.
    let reminderSync: Task<Void, Never>?

    var didWrite: Bool { !written.isEmpty }

    /// For the notification action handler: iOS may suspend the app as soon as
    /// it reports the response handled, so it waits for the queue to be
    /// consistent first. Screens do not wait.
    func waitForReminders() async {
        await reminderSync?.value
    }

    static let nothing = DoseLogOutcome(written: [], reminderSync: nil)
}

@MainActor
protocol DoseLoggingUseCaseProtocol {

    /// Doses of one slot that are not taken yet — what a tapped notification
    /// is still asking about. Matched with a one-second tolerance, because the
    /// slot time arrives from `userInfo` as a Double.
    func openDoses(medicationIds: [UUID], at slot: Date) -> [PillDose]

    /// The dashboard checkbox: flips one dose.
    @discardableResult
    func toggle(_ dose: PillDose) throws -> DoseLogOutcome

    /// Logs as taken. Doses already taken are left alone — never a toggle.
    @discardableResult
    func markTaken(_ doses: [PillDose]) throws -> DoseLogOutcome

    /// Records a deliberate skip. Doses already taken or skipped are left alone.
    @discardableResult
    func markSkipped(_ doses: [PillDose]) throws -> DoseLogOutcome

    /// Undoes a "Log all". Judged on what is stored now, so a dose the user has
    /// unticked by hand in the meantime is not touched again.
    @discardableResult
    func revertTaken(_ doses: [PillDose]) throws -> DoseLogOutcome
}
