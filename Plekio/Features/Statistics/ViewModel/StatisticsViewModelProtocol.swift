//
//  StatisticsViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI
import Combine

// MARK: - StatisticsViewModelProtocol

@MainActor
protocol StatisticsViewModelProtocol: ObservableObject {
    /// Today's logged fraction of scheduled doses, 0...1.
    var progress: Double { get }
    var streakDays: Int { get }
    var lowStockItems: [MedicationSnapshot] { get }

    func loadStats()
    /// Whether the refill was saved.
    @discardableResult
    func refill(medication: MedicationSnapshot, amount: Int) -> Bool
}
