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

    var count: Int { doses.count }
}
