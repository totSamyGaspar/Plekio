//
//  ShortcutError.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

nonisolated enum ShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case storeUnavailable
    case invalidReading(BloodPressureRules.Issue)

    /// The entry form's own wording.
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storeUnavailable:
            "Plekio can't open its data right now. Open the app to see what to do."
        case .invalidReading(.inverted):
            "Systolic must be higher than diastolic."
        case .invalidReading:
            "This reading can't be saved. Check the numbers and try again."
        }
    }
}
