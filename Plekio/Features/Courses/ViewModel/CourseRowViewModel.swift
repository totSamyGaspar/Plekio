//
//  CourseRowViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.05.2026.
//

import Foundation

struct CourseRowViewModel {

    // MARK: - Nested types

    struct Medication: Identifiable {
        let id: UUID
        let name: String
        let dosage: Int
        let systemImage: String
    }

    // MARK: - Properties

    let title: String

    /// Sorted by name: SwiftData to-many relationships have no stable order.
    let medications: [Medication]

    var medicationsCount: Int { medications.count }

    let dateRangeText: String
    let totalDays: Int
    let currentDayNumber: Int
    let daysProgress: Double

    // MARK: - Init

    /// `now` is injectable so tests can pin the progress date.
    init(course: CourseSnapshot, today now: Date = Date()) {
        self.title = course.name
        self.medications = course.medications
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map {
                Medication(id: $0.id, name: $0.name, dosage: $0.dosage, systemImage: $0.formSystemImage)
            }

        let rangeStart = course.startDate
        let rangeEnd = max(rangeStart, course.endDate)
        self.dateRangeText = rangeStart == rangeEnd
        ? rangeStart.formatted(date: .abbreviated, time: .omitted)
        : (rangeStart ..< rangeEnd).formatted(date: .abbreviated, time: .omitted)

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: course.startDate)
        let end = calendar.startOfDay(for: course.endDate)
        let total =
        (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        self.totalDays = total

        let today = calendar.startOfDay(for: now)
        if today < start {
            self.currentDayNumber = 0
        } else {
            let components = calendar.dateComponents(
                [.day],
                from: start,
                to: today
            )
            let daysPassed = (components.day ?? 0) + 1
            self.currentDayNumber = min(daysPassed, total)
        }

        self.daysProgress =
        total > 0 ? Double(self.currentDayNumber) / Double(total) : 0
    }
}
