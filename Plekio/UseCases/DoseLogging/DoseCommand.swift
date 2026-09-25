//
//  DoseCommand.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - DoseCommand

enum DoseCommand: Equatable {
    case take([PillDose])
    case skip([PillDose])
    case revertTake([PillDose])
    case revertSkip([PillDose])

    var inverse: DoseCommand {
        switch self {
        case .take(let doses): return .revertTake(doses)
        case .revertTake(let doses): return .take(doses)
        case .skip(let doses): return .revertSkip(doses)
        case .revertSkip(let doses): return .skip(doses)
        }
    }

    /// Only slot and medication matter; commands run against stored state, not these copies.
    var doses: [PillDose] {
        switch self {
        case .take(let doses), .skip(let doses), .revertTake(let doses), .revertSkip(let doses):
            return doses
        }
    }
}
