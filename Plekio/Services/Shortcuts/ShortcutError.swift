//
//  ShortcutError.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Foundation

nonisolated enum ShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case storeUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storeUnavailable:
            "Plekio can't open its data right now. Open the app to see what to do."
        }
    }
}
