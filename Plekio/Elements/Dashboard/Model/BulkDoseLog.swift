//
//  BulkDoseLog.swift
//  Plekio
//
//  (File name kept from when this was only "Log all"; the type is
//  UndoableDoseAction now.)
//

import Foundation

/// The last dose action the dashboard can still take back, for as long as the
/// undo window is open.
///
/// "Log all" and "Skip" are the actions that are both easy to hit by accident
/// and self-concealing: either one cancels the slot's reminder, so a mistap
/// costs the reminder as well as the record, and nothing would come back to
/// point it out. A confirmation on every tap would tax the most frequent
/// actions in the app to guard against a rare mistake, so the tap stays
/// immediate and this makes it reversible instead.
///
/// The single checkbox gets no banner: tapping it again is its undo.
struct UndoableDoseAction: Equatable {

    enum Kind: Equatable {
        case logged, skipped
    }

    let kind: Kind

    /// What reverses the action — the inverse the use case handed back.
    let undo: DoseCommand

    /// When the window opened. The banner counts down from here rather than from
    /// the moment it happens to appear, so a banner rebuilt mid-window — a scroll,
    /// a return from the background — resumes where the timer actually is instead
    /// of restarting a full bar that then vanishes early.
    let startedAt: Date

    var doses: [PillDose] { undo.doses }
    var count: Int { doses.count }

    /// How long the undo stays available.
    ///
    /// Long enough to notice the banner, read it and work out what it offers — the
    /// mistap is realised a beat after it happens, not during it — and still short
    /// enough that the banner is gone before it becomes furniture.
    ///
    /// Lives here because two things have to agree on it: the view model, which
    /// closes the window, and the banner, which draws it running out.
    static let window: TimeInterval = 10
}
