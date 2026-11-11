//
//  MockNewTreatmentViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

// MARK: - MockNewTreatmentViewModel

#if DEBUG
@Observable
final class MockNewTreatmentViewModel: NewTreatmentViewModelProtocol {
    var courseName: String = "Flu"
    var startDate: Date = Date()
    var endDate: Date = Date()
    var medications: [MedicationDraft] = []

    var isSaveEnabled: Bool = true

    init() {}

    @discardableResult
    func saveCourse() -> Bool { true }
    func addMedication(_ draft: MedicationDraft) {}
    func deleteMedication(at offsets: IndexSet) {}
}
#endif
