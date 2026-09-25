//
//  CourseEditingUseCase.swift
//  Plekio
//
//  Works on snapshots and ids, through CourseRepository — it never holds a
//  SwiftData model, so neither does anything that calls it.
//

import Foundation

@MainActor
final class CourseEditingUseCase: CourseEditingUseCaseProtocol {

    private let courses: any CourseRepository
    private let notificationService: NotificationServiceProtocol

    init(courses: any CourseRepository, notificationService: NotificationServiceProtocol) {
        self.courses = courses
        self.notificationService = notificationService
    }

    /// Over the SwiftData store — the shape tests and the old call sites use.
    convenience init(dbService: any CourseStoring, notificationService: NotificationServiceProtocol) {
        self.init(courses: SwiftDataCourseRepository(store: dbService), notificationService: notificationService)
    }

    // MARK: - Creating and editing

    func createCourse(name: String, startDate: Date, endDate: Date, medications: [MedicationDraft]) throws {
        try courses.createCourse(name: name, startDate: startDate, endDate: endDate, medications: medications)
    }

    func updateDetails(of course: CourseSnapshot, name: String, startDate: Date, endDate: Date) throws -> Bool {
        guard course.name != name || course.startDate != startDate || course.endDate != endDate else {
            return false
        }
        try courses.updateCourse(id: course.id, name: name, startDate: startDate, endDate: endDate)
        return true
    }

    func addMedication(_ draft: MedicationDraft, to course: CourseSnapshot) throws {
        try courses.addMedication(draft, toCourse: course.id)
    }

    func updateMedication(_ medication: MedicationSnapshot, with draft: MedicationDraft) throws {
        try courses.updateMedication(id: medication.id, with: draft)
    }

    func repeatCourse(_ course: CourseSnapshot, startDate: Date, endDate: Date) throws -> Bool {
        // Checked against storage, not against whatever list a screen last
        // fetched: the rule has to hold whoever calls this.
        let active = courses.allCourses().filter { $0.isActive() }
        guard !course.hasActiveRepeat(among: active) else { return false }

        try courses.duplicateCourse(id: course.id, startDate: startDate, endDate: endDate)
        return true
    }

    // MARK: - Deleting

    func deleteMedications(_ medications: [MedicationSnapshot]) throws {
        // Cleaned up in `defer`, so if the third delete fails, the two that
        // succeeded still lose their banners.
        var deleted: [UUID] = []
        defer { clearDeliveredReminders(for: deleted) }

        for medication in medications {
            try courses.deleteMedication(id: medication.id)
            deleted.append(medication.id)
        }
    }

    func deleteCourse(_ course: CourseSnapshot) throws {
        try courses.deleteCourse(id: course.id)
        clearDeliveredReminders(for: course.medications.map(\.id))
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
