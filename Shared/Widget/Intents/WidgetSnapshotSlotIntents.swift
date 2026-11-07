//
//  WidgetSnapshotSlotIntents.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents
import Foundation

extension WidgetSnapshot.Slot {

    /// Takes the slot's open doses: what the hero card's "LOG ALL" does.
    var takeOpenDoses: TakeDosesIntent {
        TakeDosesIntent(slot: time, medicationIds: doses.filter { $0.status == .pending }.map(\.medicationId))
    }

    var skipOpenDoses: SkipDosesIntent {
        SkipDosesIntent(slot: time, medicationIds: doses.filter { $0.status == .pending }.map(\.medicationId))
    }

    func take(_ dose: WidgetSnapshot.Dose) -> TakeDosesIntent {
        TakeDosesIntent(slot: time, medicationIds: [dose.medicationId])
    }

    /// Flips the dose: an open one gets taken, a taken one un-logged.
    func toggle(_ dose: WidgetSnapshot.Dose) -> ToggleDoseIntent {
        ToggleDoseIntent(slot: time, medicationId: dose.medicationId, taken: dose.status != .taken)
    }
}
