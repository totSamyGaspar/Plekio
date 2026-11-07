//
//  WidgetSnapshotSlotLink.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

extension WidgetSnapshot.Slot {

    /// The take-dose sheet for what is still open in the slot; Today once nothing is.
    var openLink: WidgetLink {
        let open = doses.filter { $0.status == .pending }.map(\.medicationId)
        return open.isEmpty ? .today : .dose(slot: time, medicationIds: open)
    }
}
