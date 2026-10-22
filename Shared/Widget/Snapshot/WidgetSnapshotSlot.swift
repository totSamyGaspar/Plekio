//
//  WidgetSnapshotSlot.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

extension WidgetSnapshot {

    /// The doses due at one time of day, like one "Up next" card.
    nonisolated struct Slot: Codable, Equatable, Sendable, Identifiable {
        var time: Date
        var period: Period
        var doses: [Dose]

        var id: Date { time }
    }
}
