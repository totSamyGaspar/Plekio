//
//  WidgetSnapshot+StockAlert.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - StockAlert

extension WidgetSnapshot {

    nonisolated struct StockAlert: Codable, Equatable, Sendable, Identifiable {
        var medicationId: UUID
        var name: String
        var stock: Int
        var threshold: Int

        var id: UUID { medicationId }
    }
}
