//
//  CourseEditingUseCase.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

@MainActor
final class CourseEditingUseCase: CourseEditingUseCaseProtocol {

    // MARK: - Properties

    private let courses: any CourseRepository
    private let notificationService: NotificationServiceProtocol
    private let time: any TimeSource

    // MARK: - Init

    init(courses: any CourseRepository, notificationService: NotificationServiceProtocol, time: any TimeSource = SystemTime()) {
        self.time = time
        self.courses = courses
        self.notificationService = notificationService
    }

    /// Backed by the SwiftData store.
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
        // Checked against storage, not a screen's cached list, so the rule holds for any caller.
        let now = time.now
        let active = courses.allCourses().filter { $0.isActive(on: now, calendar: time.calendar) }
        guard !course.hasActiveRepeat(among: active) else { return false }

        try courses.duplicateCourse(id: course.id, startDate: startDate, endDate: endDate)
        return true
    }

    // MARK: - Deleting

    func deleteMedications(_ medications: [MedicationSnapshot]) throws {
        // `defer` so medications deleted before a failure still get cleaned up.
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

    /// Removes already-delivered reminders (the rebuild only drops pending ones).
    /// NotificationService serializes this with the rebuild.
    private func clearDeliveredReminders(for medicationIds: [UUID]) {
        guard !medicationIds.isEmpty else { return }
        Task { [notificationService] in
            for id in medicationIds {
                await notificationService.cancelNotifications(for: id)
            }
        }
    }
}
