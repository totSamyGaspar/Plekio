//
//  StockRules.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Foundation

nonisolated enum StockRules {

    /// At or below the threshold counts as low: the warning shows while there is still some left.
    static func isLow(stock: Int, threshold: Int) -> Bool {
        stock <= threshold
    }
}

// MARK: - MedicationItem

nonisolated extension MedicationItem {

    var isLowOnStock: Bool {
        StockRules.isLow(stock: stockCount, threshold: lowStockThreshold)
    }
}
