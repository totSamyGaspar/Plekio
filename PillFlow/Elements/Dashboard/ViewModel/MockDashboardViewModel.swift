//
//  MockDashboardViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

final class MockDashboardViewModel: DashboardViewModelProtocol {
    
    @Published var selectedDate: Date = Date()
    
    var weekDates: [Date] = [Date()]
    
    var morningPills: [PillDose] = [
        PillDose(medicationId: UUID(), name: "Витамин D", dosage: "1 капсула", formSystemImage: "pills.fill", time: Date(), period: .morning, isTaken: false)
    ]
    var noonPills: [PillDose] = []
    var eveningPills: [PillDose] = []
    
    var isEmpty: Bool = false
    
    // Fake data for the weekly adherence chart preview
    @Published var weeklyPercentages: [Double] = [1.0, 1.0, 1.0, 0.6, 1.0, 0.7, 1.0]
    @Published var weeklyDays: [String] = ["Fri", "Sat", "Sun", "Mon", "Tue", "Wed", "Thu"]
    @Published var recentAverage: Int = 93
    
    init() {}
    
    func togglePill(id: UUID) {}
    
    func handlePushTap(medicationId: UUID, time: Date, completion: @escaping (PillDose?) -> Void) {
        completion(morningPills.first)
    }
}
