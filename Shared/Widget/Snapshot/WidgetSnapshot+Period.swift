//
//  WidgetSnapshot+Period.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - Period

extension WidgetSnapshot {

    nonisolated enum Period: String, Codable, Sendable {
        case morning, afternoon, evening
    }
}
