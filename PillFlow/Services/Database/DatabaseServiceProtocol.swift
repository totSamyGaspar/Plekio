//
//  DatabaseServiceProtocol.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Foundation
import SwiftData

@MainActor
protocol DatabaseServiceProtocol {
    func saveCourse(name: String, startDate: Date, endDate: Date, drafts: [MedicationDraft])
    func togglePill(medicationId: UUID, scheduledTime: Date)
    
    func fetchPills(for date: Date, preFetchedCourses: [TreatmentCourse]?) -> [PillDose]
    func fetchAllCourses() -> [TreatmentCourse]
    func deleteCourse(_ course: TreatmentCourse)
    func deleteMedication(_ medication: MedicationItem)
    
    func updateCourseDetails(course: TreatmentCourse, name: String, startDate: Date, endDate: Date)
    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft)
    func addMedication(draft: MedicationDraft, to course: TreatmentCourse)
    func refillStock(for medication: MedicationItem, amount: Int)
    
}
