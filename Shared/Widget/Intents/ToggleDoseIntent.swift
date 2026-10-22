//
//  ToggleDoseIntent.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents
import Foundation

// MARK: - ToggleDoseIntent

/// One medication's check, as a `Toggle(isOn:intent:)`: WidgetKit shows the new
/// state the moment it is tapped, while the work runs in the app. Taking it back
/// un-logs the dose, like the checkbox on Today.
///
/// What to do is decided when the widget is drawn (`taken`), not handed in by the
/// system as a SetValueIntent's `value`: that combination left the dose unwritten
/// on device, and the toggle sprang back.
struct ToggleDoseIntent: LiveActivityIntent {

    nonisolated static let title: LocalizedStringResource = "Log dose"
    nonisolated static let isDiscoverable = false

    /// The state to set: true takes the dose, false un-logs it.
    @Parameter(title: "Taken") var taken: Bool
    @Parameter(title: "Medications") var medicationIds: [String]
    @Parameter(title: "Time") var slotTime: Double

    init() {}

    init(slot: Date, medicationId: UUID, taken: Bool) {
        self.taken = taken
        self.medicationIds = [medicationId.uuidString]
        self.slotTime = slot.timeIntervalSince1970
    }

    var ids: [UUID] { medicationIds.compactMap(UUID.init(uuidString:)) }
    var slot: Date { Date(timeIntervalSince1970: slotTime) }
}
