//
//  NewTreatmentViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

protocol NewTreatmentViewModelProtocol: ObservableObject {
    var courseName: String { get set }
    var startDate: Date { get set }
    var endDate: Date { get set }
    
    var medications: [MedicationDraft] { get set }
    
    var isSaveEnabled: Bool { get }
    
    func addMedication(_ draft: MedicationDraft)
    func deleteMedication(at offset: IndexSet)
    /// Returns false if the save failed — the screen then stays open.
    @discardableResult
    func saveCourse() -> Bool
}
