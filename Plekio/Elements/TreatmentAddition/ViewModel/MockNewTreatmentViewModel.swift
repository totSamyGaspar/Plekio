//
//  MockNewTreatmentViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

// #Preview only, and behind #if DEBUG: unguarded, a mock in the main target
// ships in the release binary.
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
