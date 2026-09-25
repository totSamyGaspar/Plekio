//
//  ReportSections.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import UIKit

/// Draws the report body. Each section method returns the page index of its
/// heading, used for the PDF bookmarks.
nonisolated struct ReportSections {

    // MARK: - Properties

    let canvas: PageCanvas
    let photos: [UUID: UIImage]

    private var style: ReportStyle { canvas.style }

    private var day: Date.FormatStyle { .dateTime.day().month(.abbreviated).year() }
    private var dayTime: Date.FormatStyle { .dateTime.day().month(.abbreviated).year().hour().minute() }

    // MARK: - Medications

    @discardableResult
    func medications(_ courses: [CourseReport]) -> Int {
        let page = heading(String(localized: "Medications"))

        for course in courses {
            canvas.reserve(80)
            canvas.write(course.name, font: style.heading, gap: 2)
            canvas.write(
                "\(course.startDate.formatted(day)) — \(course.endDate.formatted(day))",
                font: style.caption,
                color: style.mutedInk,
                gap: 4
            )
            canvas.write(summary(course.adherence), font: style.subheading, color: style.accent, gap: 8)

            for medication in course.medications {
                self.medication(medication)
            }

            canvas.space(style.sectionGap)
        }
        return page
    }

    private func medication(_ medication: MedicationReport) {
        canvas.reserve(48)

        let schedule = String(localized: DoseFrequency.title(forDays: medication.frequencyDays))
        canvas.write(
            "\(medication.name) · \(String(localized: "\(medication.dosage) pcs")) · \(schedule)",
            font: style.body,
            indent: 14,
            gap: 2
        )
        canvas.write(
            summary(medication.adherence),
            font: style.caption,
            color: style.secondaryInk,
            indent: 14,
            gap: 4
        )

        exceptions(medication.exceptions)
    }

    /// Skipped/missed doses, capped so long courses don't flood the document.
    private func exceptions(_ exceptions: [DoseException]) {
        guard !exceptions.isEmpty else { return }

        let limit = 12

        for exception in exceptions.prefix(limit) {
            let label = exception.kind == .skipped
                ? String(localized: "Skipped")
                : String(localized: "Missed")

            canvas.write(
                "\(exception.time.formatted(dayTime)) — \(label)",
                font: style.caption,
                color: style.mutedInk,
                indent: 28,
                gap: style.rowGap
            )
        }

        if exceptions.count > limit {
            canvas.write(
                String(localized: "\(exceptions.count - limit) more"),
                font: style.caption,
                color: style.mutedInk,
                indent: 28,
                gap: style.rowGap
            )
        }

        canvas.space(6)
    }

    private func summary(_ adherence: Adherence) -> String {
        var parts = [
            "\(String(localized: "Taken")) \(adherence.taken)",
            "\(String(localized: "Skipped")) \(adherence.skipped)",
            "\(String(localized: "Missed")) \(adherence.missed)"
        ]

        if let rate = adherence.rate {
            parts.append(rate.formatted(.percent.precision(.fractionLength(0))))
        }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: - Blood pressure

    @discardableResult
    func pressure(_ readings: [PressureReading]) -> Int {
        let page = heading(String(localized: "Blood Pressure"))

        let columns: (date: CGFloat, value: CGFloat, pulse: CGFloat) = (0, 220, 330)

        canvas.row(
            [(String(localized: "Date"), columns.date),
             (String(localized: "Pressure"), columns.value),
             (String(localized: "Pulse"), columns.pulse)],
            font: style.tableHeader,
            color: style.mutedInk,
            gap: 3
        )
        canvas.rule()
        canvas.space(5)

        for reading in readings {
            canvas.row(
                [(reading.measuredAt.formatted(dayTime), columns.date),
                 ("\(reading.systolic)/\(reading.diastolic)", columns.value),
                 (reading.pulse.map(String.init) ?? "—", columns.pulse)],
                font: style.body,
                gap: style.rowGap
            )
        }

        canvas.space(style.sectionGap)
        return page
    }

    // MARK: - Diary

    @discardableResult
    func diary(_ days: [DiaryDay]) -> Int {
        let page = heading(String(localized: "Diary"))

        for entry in days {
            canvas.reserve(70)
            canvas.write(entry.date.formatted(dayTime), font: style.subheading, gap: 3)
            canvas.write(measures(of: entry), font: style.body, color: style.secondaryInk, indent: 14, gap: 3)

            if !entry.symptoms.isEmpty {
                canvas.write(
                    "\(String(localized: "Symptoms")): \(entry.symptoms.joined(separator: ", "))",
                    font: style.body,
                    color: style.secondaryInk,
                    indent: 14,
                    gap: 3
                )
            }

            if !entry.notes.isEmpty {
                canvas.write(entry.notes, font: style.body, indent: 14, gap: 4)
            }

            images(of: entry)
            canvas.space(10)
        }

        canvas.space(style.sectionGap)
        return page
    }

    /// Quick-log entries show mood only; their other fields were never measured.
    private func measures(of entry: DiaryDay) -> String {
        var parts = [String(localized: "Mood: \(entry.mood)")]

        guard !entry.isQuickLog else { return parts.joined(separator: "  ·  ") }

        parts.append(String(localized: "Energy: \(entry.energyLevel)/5"))
        parts.append(String(localized: "Discomfort/Pain: \(entry.discomfortLevel)/10"))
        parts.append("\(String(localized: "Sleep")): \(entry.sleepHours.formatted(.number.precision(.fractionLength(0...1))))")
        parts.append("\(String(localized: "Water")): \(entry.waterGlasses)")

        return parts.joined(separator: "  ·  ")
    }

    private func images(of entry: DiaryDay) {
        let available = entry.photoIds.compactMap { photos[$0] }
        guard !available.isEmpty else { return }

        for image in available {
            canvas.image(image, height: 110, x: style.margin + 14, gap: 6)
        }
    }

    // MARK: - Helpers

    private func heading(_ title: String) -> Int {
        canvas.reserve(70)

        let page = canvas.write(title, font: style.heading, color: style.accent, gap: 3)
        canvas.rule()
        canvas.space(8)

        return page
    }
}
