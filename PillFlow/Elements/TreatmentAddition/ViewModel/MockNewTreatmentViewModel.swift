//
//  MockNewTreatmentViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

// #Preview only. Mocks used to sit in the main target without an #if DEBUG
// guard and shipped in the release binary.
#if DEBUG
final class MockNewTreatmentViewModel: NewTreatmentViewModelProtocol {
    @Published var courseName: String = "Flu"
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()
    @Published var medications: [MedicationDraft] = []
    
    var isSaveEnabled: Bool = true
    
    init() {}
    
    @discardableResult
    func saveCourse() -> Bool { true }
    func addMedication(_ draft: MedicationDraft) {}
    func deleteMedication(at offsets: IndexSet) {}
}

#endif
