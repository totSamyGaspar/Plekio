//
//  NewTreatmentViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

@MainActor
@Observable
final class NewTreatmentViewModel: NewTreatmentViewModelProtocol {

    // MARK: - Properties

    var courseName: String = ""
    /// Today, and a week later; set from `time` in init.
    var startDate: Date
    var endDate: Date
    var medications: [MedicationDraft] = []

    private let courseEditing: CourseEditingUseCaseProtocol
    private let errors: any ErrorReporting

    // MARK: - Init

    /// Reminders sync to the new course on their own (ReminderSyncCoordinator).
    init(courseEditing: CourseEditingUseCaseProtocol, errors: any ErrorReporting, time: any TimeSource = SystemTime()) {
        self.courseEditing = courseEditing
        self.errors = errors
        let now = time.now
        startDate = now
        endDate = time.calendar.date(byAdding: .day, value: 7, to: now) ?? now
    }

    // MARK: - Actions

    var isSaveEnabled: Bool {
        !courseName.trimmingCharacters(in: .whitespaces).isEmpty && !medications.isEmpty
    }

    func addMedication(_ draft: MedicationDraft) { medications.append(draft) }
    func deleteMedication(at offsets: IndexSet) { medications.remove(atOffsets: offsets) }

    /// Returns `false` if the save failed, so the screen stays open.
    @discardableResult
    func saveCourse() -> Bool {
        guard errors.run({
            try courseEditing.createCourse(name: courseName, startDate: startDate, endDate: endDate, medications: medications)
        }) else { return false }

        return true
    }
}
