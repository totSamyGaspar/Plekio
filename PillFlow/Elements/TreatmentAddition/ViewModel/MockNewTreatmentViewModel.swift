//
//  MockNewTreatmentViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

final class MockNewTreatmentViewModel: NewTreatmentViewModelProtocol {
    @Published var courseName: String = "Грипп"
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()
    @Published var medications: [MedicationDraft] = []
    
    var isSaveEnabled: Bool = true
    
    init() {}
    
    func saveCourse() {}
    func addMedication(_ draft: MedicationDraft) {}
    func deleteMedication(at offsets: IndexSet) {}
}
