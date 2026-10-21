//
//  DoseIntents.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import AppIntents
import Foundation

// The widget's buttons. LiveActivityIntent, not a plain AppIntent: the system then
// runs them in the app's process (woken in the background if need be), where the
// dose goes through the same path as a notification's Take or Skip — store write,
// stock, reminders, badge and snapshot. That needs NSSupportsLiveActivities in the
// app's Info.plist; no Live Activity is ever started.
//
// The types live here because both targets must know them: the widget to build its
// buttons, the app to run them. `perform()` is in each target's own extension:
// DoseIntents+App.swift does the work, DoseIntents+Widget.swift is never called.
//
// Not `nonisolated` as a whole: that would reach the @Parameter properties, which
// it can't apply to. In the app (MainActor by default) only what the protocol
// reads without an actor is marked: `title` and `isDiscoverable`.

// MARK: - TakeDosesIntent

struct TakeDosesIntent: LiveActivityIntent {

    nonisolated static let title: LocalizedStringResource = "Take doses"
    /// A widget button, not an action for Shortcuts or Siri.
    nonisolated static let isDiscoverable = false

    /// Strings and a plain number: what an intent parameter carries without an AppEntity.
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

// MARK: - SkipDosesIntent

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

// MARK: - Slot

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
