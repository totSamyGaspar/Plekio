//
//  StatisticsViewModelProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI
import Combine

@MainActor
protocol StatisticsViewModelProtocol: ObservableObject {
    var takenCount: Int { get }
    var totalCount: Int { get }
    var progress: Double { get }
    var streakDays: Int { get }
    var lowStockItems: [MedicationItem] { get }
    
    func loadStats()
    func refill(medication: MedicationItem, amount: Int)
}
