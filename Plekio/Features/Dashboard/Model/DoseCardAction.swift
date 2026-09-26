//
//  DoseCardAction.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Foundation

/// Everything a dose card can ask for; the card reports it, the screen carries it out.
enum DoseCardAction: Hashable {
    /// Log, or undo a log (the checkmark).
    case toggle
    /// Open the confirmation sheet (tap on the card).
    case open
    case skip
    case showCourse

    // MARK: - Menu

    /// The long-press menu for `pill`, in display order.
    static func menu(for pill: PillDose, at now: Date = Date()) -> [DoseCardAction] {
        var actions: [DoseCardAction] = []
        if pill.isLoggable(at: now) {
            actions.append(.toggle)
            if pill.status == .pending { actions.append(.skip) }
        }
        if pill.courseId != nil { actions.append(.showCourse) }
        return actions
    }

    // MARK: - Presentation

    func title(for pill: PillDose) -> LocalizedStringResource {
        switch self {
        case .toggle: return pill.isTaken ? "Undo logging" : "Log dose"
        case .open: return "Log dose"
        case .skip: return "Skip dose"
        case .showCourse: return "Open course"
        }
    }

    func systemImage(for pill: PillDose) -> String {
        switch self {
        case .toggle: return pill.isTaken ? "arrow.uturn.backward" : "checkmark.circle"
        case .open: return "checkmark.circle"
        case .skip: return "forward.end"
        case .showCourse: return "list.clipboard"
        }
    }
}
