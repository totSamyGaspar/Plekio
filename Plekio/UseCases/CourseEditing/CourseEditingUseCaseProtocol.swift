//
//  CourseEditingUseCaseProtocol.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - CourseEditingUseCaseProtocol

@MainActor
protocol CourseEditingUseCaseProtocol {

    func createCourse(name: String, startDate: Date, endDate: Date, medications: [MedicationDraft]) throws

    /// Writes only if something changed (avoids a reminder rebuild); returns whether it wrote.
    @discardableResult
    func updateDetails(of course: CourseSnapshot, name: String, startDate: Date, endDate: Date) throws -> Bool

    func addMedication(_ draft: MedicationDraft, to course: CourseSnapshot) throws
    func updateMedication(_ medication: MedicationSnapshot, with draft: MedicationDraft) throws

    /// Also removes the medications' delivered reminders.
    func deleteMedications(_ medications: [MedicationSnapshot]) throws

    /// Deletes the course with its medications, and their delivered reminders.
    func deleteCourse(_ course: CourseSnapshot) throws

    /// Copies the course with new dates; returns false and writes nothing if a repeat is already active.
    @discardableResult
    func repeatCourse(_ course: CourseSnapshot, startDate: Date, endDate: Date) throws -> Bool
}
