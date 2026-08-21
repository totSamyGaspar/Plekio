//
//  CourseDetailViewModelProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

@MainActor
protocol CourseDetailViewModelProtocol: ObservableObject {
    var course: TreatmentCourse { get }
    var medications: [MedicationItem] { get }
    
    var courseName: String { get set }
    var startDate: Date { get set }
    var endDate: Date { get set }
    
    func saveCourseChanges()
    func deleteMedication(at offsets: IndexSet)
    func addNewMedication(_ draft: MedicationDraft)
    func updateMedication(medication: MedicationItem, with draft: MedicationDraft)
}
