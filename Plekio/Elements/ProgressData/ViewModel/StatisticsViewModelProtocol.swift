//
//  StatisticsViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI
import Combine

@MainActor
protocol StatisticsViewModelProtocol: ObservableObject {
    // takenCount/totalCount stay on StatisticsViewModel itself (the tests read
    // them), but the screen only uses the derived progress. Putting them in the
    // protocol would force every implementation to duplicate them.
    var progress: Double { get }
    var streakDays: Int { get }
    var lowStockItems: [MedicationItem] { get }
    
    func loadStats()
    func refill(medication: MedicationItem, amount: Int)
}
