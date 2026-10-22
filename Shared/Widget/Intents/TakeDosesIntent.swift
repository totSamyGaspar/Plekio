//
//  TakeDosesIntent.swift
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
// the app's *Intent+Perform.swift files do the work; the widget's
// *Intent+Widget.swift ones are never called.
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
