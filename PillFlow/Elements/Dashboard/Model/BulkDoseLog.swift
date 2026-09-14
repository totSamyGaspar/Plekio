//
//  BulkDoseLog.swift
//  PillFlow
//

import Foundation

/// The doses logged by one tap of "Log all", kept only long enough to undo them.
///
/// "Log all" is the one action in the app that is both easy to hit by accident
/// and self-concealing: logging a dose cancels its reminder, so a mistap costs
/// the reminder as well as the record, and nothing would come back to point it
/// out. A confirmation on every tap would tax the most frequent action in the
/// app several times a day to guard against a rare mistake, so the tap stays
/// immediate and this makes it reversible instead.
struct BulkDoseLog: Equatable {
    let doses: [PillDose]

    /// When the window opened. The banner counts down from here rather than from
    /// the moment it happens to appear, so a banner rebuilt mid-window — a scroll,
    /// a return from the background — resumes where the timer actually is instead
    /// of restarting a full bar that then vanishes early.
    let loggedAt: Date = Date()

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
