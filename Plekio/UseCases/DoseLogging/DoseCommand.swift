//
//  DoseCommand.swift
//  Plekio
//
//  A dose action as a value: what was done to which doses. The use case runs
//  one with `perform(_:)`, and every action it runs hands back its `inverse`
//  in the outcome — so an undo is simply the next command, not a special path
//  per screen.
//
//  Before this, the only undo in the app was for "Log all", wired by hand in
//  the dashboard: remember the doses, call `revertTaken` on them. A skip could
//  not be taken back at all — a skipped dose had no way back to "not answered".
//

import Foundation

enum DoseCommand: Equatable {
    case take([PillDose])
    case skip([PillDose])
    case revertTake([PillDose])
    case revertSkip([PillDose])

    /// The command that takes this one back.
    var inverse: DoseCommand {
        switch self {
        case .take(let doses): return .revertTake(doses)
        case .revertTake(let doses): return .take(doses)
        case .skip(let doses): return .revertSkip(doses)
        case .revertSkip(let doses): return .skip(doses)
        }
    }

    /// Which doses it names. Only their slots and medications matter: every
    /// command is judged against what is stored when it runs, not against the
    /// state these copies were in when it was recorded.
    var doses: [PillDose] {
        switch self {
        case .take(let doses), .skip(let doses), .revertTake(let doses), .revertSkip(let doses):
            return doses
        }
    }
}
