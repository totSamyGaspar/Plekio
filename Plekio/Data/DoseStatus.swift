//
//  DoseStatus.swift
//  Plekio
//
//  What the user has answered for one scheduled dose — as one value.
//
//  It used to be four independent fields on DoseLog: `isTaken`,
//  `actualTakeTime`, `skippedAt`, `dispensedQuantity`. Nothing stopped a log
//  from being both taken and skipped, or taken with no time, or un-taken with a
//  quantity still recorded — and every writer had to remember which fields to
//  clear together, which the comments in DatabaseService kept reminding it to
//  do. As an enum, those combinations cannot be written down at all, and the
//  moves between states are named once, here.
//

import Foundation

nonisolated enum DoseStatus: Equatable, Sendable {

    /// Not answered yet — still due, or forgotten.
    case pending

    /// Logged as taken.
    ///
    /// `at` is when it was logged, which is how lateness is captured: for a
    /// back-dated dose it is after the scheduled time. `dispensed` is how many
    /// units actually left the stock — not the dosage: stock is clamped at
    /// zero, so a dose logged at an empty bottle takes out less, maybe nothing.
    /// Nil only for a log written before the quantity was recorded.
    case taken(at: Date, dispensed: Int?)

    /// Deliberately passed on. Not the same as pending: the statistics tell a
    /// declined dose from a forgotten one, and the reminder rebuild leaves a
    /// skipped slot alone while a pending one gets its reminder back.
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

    /// Answered for, one way or the other: "do not ring for this one".
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

    // MARK: - Moves
    //
    // Each returns the new status, or nil when the move does not apply — so a
    // bulk action over doses in unknown states can never reverse what it finds.

    /// Taking overrides an earlier skip. Already taken: no move.
    func taking(at date: Date, dispensed: Int) -> DoseStatus? {
        isTaken ? nil : .taken(at: date, dispensed: dispensed)
    }

    /// A taken dose is not skippable. Skipping again moves the timestamp.
    func skipping(at date: Date) -> DoseStatus? {
        isTaken ? nil : .skipped(at: date)
    }

    /// Un-logs a taken dose. Returns what to credit back to the stock: exactly
    /// what went out, or nil when the log predates that record — the caller then
    /// has only the dosage to go by.
    func reverting() -> (status: DoseStatus, credit: Int?)? {
        guard case .taken(_, let dispensed) = self else { return nil }
        return (.pending, dispensed)
    }
}
