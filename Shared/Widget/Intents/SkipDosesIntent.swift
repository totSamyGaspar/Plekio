//
//  SkipDosesIntent.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents
import Foundation

struct SkipDosesIntent: LiveActivityIntent {

    nonisolated static let title: LocalizedStringResource = "Skip doses"
    nonisolated static let isDiscoverable = false

    @Parameter(title: "Medications") var medicationIds: [String]
    @Parameter(title: "Time") var slotTime: Double

    init() {}

    init(slot: Date, medicationIds: [UUID]) {
        self.medicationIds = medicationIds.map(\.uuidString)
        self.slotTime = slot.timeIntervalSince1970
    }

    var ids: [UUID] { medicationIds.compactMap(UUID.init(uuidString:)) }
    var slot: Date { Date(timeIntervalSince1970: slotTime) }
}
