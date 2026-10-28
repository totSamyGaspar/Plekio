//
//  ShortcutBloodPressureActions.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.10.2026.
//

import Foundation

/// Saves a reading said to Siri, measured now, through the same rules as the
/// entry form. Errors are thrown so Siri can say what to fix.
@MainActor
enum ShortcutBloodPressureActions {

    static func log(systolic: Int, diastolic: Int, pulse: Int?) async throws {
        let dependencies = try ShortcutContext.dependencies()
        let now = dependencies.time.now

        if let issue = BloodPressureRules.issue(
            systolic: systolic, diastolic: diastolic, pulse: pulse, measuredAt: now, now: now
        ) {
            throw ShortcutError.invalidReading(issue)
        }
        // False only when the write failed; BloodPressureLogging has reported it.
        guard dependencies.bloodPressureLogging.save(
            measuredAt: now, systolic: systolic, diastolic: diastolic, pulse: pulse
        ) else {
            throw ShortcutError.storeUnavailable
        }
        await dependencies.widgetSnapshots.refresh().value
    }
}
