//
//  DoseStatus.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

nonisolated enum DoseStatus: Equatable, Sendable {

    // MARK: - Cases

    /// Not answered yet — still due, or forgotten.
    case pending

    /// `at` is the log time (captures lateness). `dispensed` is units that left
    /// the stock, not the dosage — stock clamps at zero. Nil on legacy logs.
    case taken(at: Date, dispensed: Int?)

    /// Deliberately declined; not the same as pending (missed). Stats count it
    /// separately and reminder rebuilds leave skipped slots alone.
    case skipped(at: Date)

    // MARK: - Reading

    var isTaken: Bool {
        if case .taken = self { return true }
        return false
    }

    var isSkipped: Bool {
        if case .skipped = self { return true }
        return false
    }

    /// Taken or skipped: no reminder should fire for it.
    var isSettled: Bool { self != .pending }

    var takenAt: Date? {
        if case .taken(let at, _) = self { return at }
        return nil
    }

    /// Units that left the stock; nil when not taken.
    var dispensed: Int? {
        if case .taken(_, let dispensed) = self { return dispensed }
        return nil
    }

    // MARK: - Transitions

    // Each returns nil when the move does not apply, so bulk actions never
    // reverse a dose's state.

    /// Overrides an earlier skip; nil when already taken.
    func taking(at date: Date, dispensed: Int) -> DoseStatus? {
        isTaken ? nil : .taken(at: date, dispensed: dispensed)
    }

    /// Nil when taken; re-skipping updates the timestamp.
    func skipping(at date: Date) -> DoseStatus? {
        isTaken ? nil : .skipped(at: date)
    }

    /// Back to pending; only from skipped.
    func unskipping() -> DoseStatus? {
        isSkipped ? .pending : nil
    }

    /// Un-logs a taken dose. `credit` is the stock to restore; nil on legacy
    /// logs, where the caller falls back to the dosage.
    func reverting() -> (status: DoseStatus, credit: Int?)? {
        guard case .taken(_, let dispensed) = self else { return nil }
        return (.pending, dispensed)
    }
}
