//
//  CourseDetailViewModelProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.05.2026.
//

import SwiftUI

// MARK: - CourseDetailViewModelProtocol

@MainActor
protocol CourseDetailViewModelProtocol: ObservableObject {
    var course: CourseSnapshot { get }
    var medications: [MedicationSnapshot] { get }

    var courseName: String { get set }
    var startDate: Date { get set }
    var endDate: Date { get set }

    func saveCourseChanges()
    func deleteMedication(at offsets: IndexSet)
    func addNewMedication(_ draft: MedicationDraft)
    func updateMedication(medication: MedicationSnapshot, with draft: MedicationDraft)
}
