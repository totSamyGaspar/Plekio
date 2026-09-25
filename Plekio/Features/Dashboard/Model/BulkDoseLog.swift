//
//  BulkDoseLog.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation

/// The last "Log all" / "Skip" action, undoable while the window is open. These
/// also cancel reminders, so a mistap would otherwise go unnoticed.
struct UndoableDoseAction: Equatable {

    // MARK: - Kind

    enum Kind: Equatable {
        case logged, skipped
    }

    // MARK: - Properties

    let kind: Kind

    /// The inverse command returned by the use case.
    let undo: DoseCommand

    /// Window start; the banner counts down from here so a rebuilt banner resumes
    /// rather than restarting.
    let startedAt: Date

    var doses: [PillDose] { undo.doses }
    var count: Int { doses.count }

    /// Undo window in seconds, shared by the view model and the banner.
    static let window: TimeInterval = 10
}
