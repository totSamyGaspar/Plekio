//
//  CourseEditingUseCase.swift
//  Plekio
//

import Foundation

@MainActor
final class CourseEditingUseCase: CourseEditingUseCaseProtocol {

    private let dbService: any CourseStoring
    private let notificationService: NotificationServiceProtocol

    init(dbService: any CourseStoring, notificationService: NotificationServiceProtocol) {
        self.dbService = dbService
        self.notificationService = notificationService
    }

    // MARK: - Creating and editing

    func createCourse(name: String, startDate: Date, endDate: Date, medications: [MedicationDraft]) throws {
        try dbService.saveCourse(name: name, startDate: startDate, endDate: endDate, drafts: medications)
    }

    func updateDetails(of course: TreatmentCourse, name: String, startDate: Date, endDate: Date) throws -> Bool {
        guard course.name != name || course.startDate != startDate || course.endDate != endDate else {
            return false
        }
        try dbService.updateCourseDetails(course: course, name: name, startDate: startDate, endDate: endDate)
        return true
    }

    func addMedication(_ draft: MedicationDraft, to course: TreatmentCourse) throws {
        try dbService.addMedication(draft: draft, to: course)
    }

    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws {
        try dbService.updateMedication(medication, with: draft)
    }

    func repeatCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws -> Bool {
        // Checked against storage, not against whatever list a screen last
        // fetched: the rule has to hold whoever calls this.
        let active = dbService.fetchAllCourses().filter { $0.isActive() }
        guard !course.hasActiveRepeat(among: active) else { return false }

        try dbService.duplicateCourse(course, startDate: startDate, endDate: endDate)
        return true
    }

    // MARK: - Deleting

    func deleteMedications(_ medications: [MedicationItem]) throws {
        // Ids are read before each delete: a deleted @Model must not be touched.
        // And cleaned up in `defer`, so if the third delete fails, the two that
        // succeeded still lose their banners.
        var deleted: [UUID] = []
        defer { clearDeliveredReminders(for: deleted) }

        for medication in medications {
            let id = medication.id
            try dbService.deleteMedication(medication)
            deleted.append(id)
        }
    }

    func deleteCourse(_ course: TreatmentCourse) throws {
        let medicationIds = course.medications.map(\.id)
        try dbService.deleteCourse(course)
        clearDeliveredReminders(for: medicationIds)
    }

    // MARK: - Side effects

    /// The coordinator's rebuild drops the PENDING reminders of a deleted
    /// medication; this is for the ones already DELIVERED, which a rebuild does
    /// not reach. NotificationService queues it with the rebuild, so the two
    /// never interleave.
    private func clearDeliveredReminders(for medicationIds: [UUID]) {
        guard !medicationIds.isEmpty else { return }
        Task { [notificationService] in
            for id in medicationIds {
                await notificationService.cancelNotifications(for: id)
            }
        }
    }
}
