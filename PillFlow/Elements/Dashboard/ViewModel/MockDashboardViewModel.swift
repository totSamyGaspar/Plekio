//
//  MockDashboardViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

#if DEBUG
final class MockDashboardViewModel: DashboardViewModelProtocol {
    
    @Published var selectedDate: Date = Date()
    
    var weekDates: [Date] = [Date()]
    
    var morningPills: [PillDose] = [
        PillDose(medicationId: UUID(), name: "Vitamin D", dosage: 1, formSystemImage: "pills.fill", time: Date(), period: .morning, isTaken: false)
    ]
    var noonPills: [PillDose] = []
    var eveningPills: [PillDose] = []
    
    var isEmpty: Bool = false
    
    @Published var weeklyPercentages: [Double] = [1.0, 1.0, 1.0, 0.6, 1.0, 0.7, 1.0]
    @Published var weeklyDays: [String] = ["Fri", "Sat", "Sun", "Mon", "Tue", "Wed", "Thu"]
    @Published var recentAverage: Int = 93
    
    init() {}
    
    @Published private(set) var undoableBulkLog: BulkDoseLog?

    func togglePill(id: PillDose.ID) {}
    func logDoses(_ doses: [PillDose]) {}
    func skipDoses(_ doses: [PillDose]) {}
    func undoBulkLog() {}
    func dismissUndo() {}
}

#endif
