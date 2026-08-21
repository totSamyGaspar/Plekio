//
//  DashboardViewModelProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation

protocol DashboardViewModelProtocol: ObservableObject {
    var selectedDate: Date { get set }
    var weekDates: [Date] { get }
    
    var morningPills: [PillDose] { get }
    var noonPills: [PillDose] { get }
    var eveningPills: [PillDose] { get }
    
    var weeklyPercentages: [Double] { get }
    var weeklyDays: [String] { get }
    var recentAverage: Int { get }
    
    var isEmpty: Bool { get }
    
    func togglePill(id: UUID)
    func handlePushTap(medicationId: UUID, time: Date, completion: @escaping (PillDose?) -> Void)
}
