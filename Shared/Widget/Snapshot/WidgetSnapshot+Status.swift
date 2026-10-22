//
//  WidgetSnapshot+Status.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - Status

extension WidgetSnapshot {

    /// Missed is not stored: it depends on the time the widget is drawn at.
    nonisolated enum Status: String, Codable, Sendable {
        case pending, taken, skipped

        var isSettled: Bool { self != .pending }
    }
}
