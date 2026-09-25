//
//  NewTreatmentViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import Combine
import SwiftUI

@MainActor
final class NewTreatmentViewModel: NewTreatmentViewModelProtocol {
    @Published var courseName: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @Published var medications: [MedicationDraft] = []
    
    private let courseEditing: CourseEditingUseCaseProtocol

    /// No notification service: the reminders follow the new course on their
    /// own — see ReminderSyncCoordinator.
    init(courseEditing: CourseEditingUseCaseProtocol) {
        self.courseEditing = courseEditing
    }
    
    var isSaveEnabled: Bool {
        !courseName.trimmingCharacters(in: .whitespaces).isEmpty && !medications.isEmpty
    }
    
    func addMedication(_ draft: MedicationDraft) { medications.append(draft) }
    func deleteMedication(at offsets: IndexSet) { medications.remove(atOffsets: offsets) }
    
    /// Returns `false` if the save failed — the view then keeps the screen open
    /// instead of losing what was typed.
    @discardableResult
    func saveCourse() -> Bool {
        guard AppErrorPresenter.shared.run({
            try courseEditing.createCourse(name: courseName, startDate: startDate, endDate: endDate, medications: medications)
        }) else { return false }

        return true
    }
}
