//
//  CourseEditingUseCaseProtocol.swift
//  Plekio
//
//  Every change to a course or its medications, from any screen.
//
//  What it does NOT do is rebuild the reminder queue: every write here announces
//  `.courses`, and ReminderSyncCoordinator follows that. What it does own is
//  what the queue rebuild cannot reach — banners already delivered for a
//  medication that no longer exists — and the rules that decide whether a write
//  should happen at all.
//

import Foundation

@MainActor
protocol CourseEditingUseCaseProtocol {

    func createCourse(name: String, startDate: Date, endDate: Date, medications: [MedicationDraft]) throws

    /// Writes only if something actually changed, so leaving the screen
    /// untouched costs no commit and no reminder rebuild. Returns whether it wrote.
    @discardableResult
    func updateDetails(of course: TreatmentCourse, name: String, startDate: Date, endDate: Date) throws -> Bool

    func addMedication(_ draft: MedicationDraft, to course: TreatmentCourse) throws
    func updateMedication(_ medication: MedicationItem, with draft: MedicationDraft) throws

    /// Deletes, and takes the medications' delivered reminders off the lock screen.
    func deleteMedications(_ medications: [MedicationItem]) throws

    /// Deletes the course with its medications, and their delivered reminders.
    func deleteCourse(_ course: TreatmentCourse) throws

    /// A copy of a finished course with new dates. Refused — returns false,
    /// writes nothing — while the treatment is already running again.
    @discardableResult
    func repeatCourse(_ course: TreatmentCourse, startDate: Date, endDate: Date) throws -> Bool
}
