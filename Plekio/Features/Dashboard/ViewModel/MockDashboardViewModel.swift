//
//  MockDashboardViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

#if DEBUG
@Observable
final class MockDashboardViewModel: DashboardViewModelProtocol {

    // MARK: - Properties

    var selectedDate: Date = Date()

    var weekDates: [Date] = [Date()]

    var morningPills: [PillDose] = [
        PillDose(medicationId: UUID(), name: "Vitamin D", dosage: 1, form: .pill, time: Date(), period: .morning)
    ]
    var noonPills: [PillDose] = []
    var eveningPills: [PillDose] = []

    var isEmpty: Bool = false
    var hasCourses: Bool = true

    var weeklyPercentages: [Double] = [1.0, 1.0, 1.0, 0.6, 1.0, 0.7, 1.0]
    var weeklyDays: [String] = ["Fri", "Sat", "Sun", "Mon", "Tue", "Wed", "Thu"]
    var recentAverage: Int = 93

    init() {}

    private(set) var undoableAction: UndoableDoseAction?

    // MARK: - Actions

    func togglePill(id: PillDose.ID) {}
    func logDoses(_ doses: [PillDose]) {}
    func skipDose(id: PillDose.ID) {}
    func undoLastAction() {}
    func dismissUndo() {}
}

#endif
