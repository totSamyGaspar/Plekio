//
//  DoseDay.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation

// MARK: - DoseDay

/// One day's doses built from the courses. `nonisolated` so both the main-actor
/// store and BackgroundReader, on its own context, build them the same way.
nonisolated enum DoseDay {

    /// Sorted by time. `day` must be a start of day in `calendar`.
    static func pills(of courses: [TreatmentCourse], on day: Date, calendar: Calendar) -> [PillDose] {
        pills(of: courses, on: day, calendar: calendar) { med in
            DoseSchedule.logsBySlot(of: med, on: day, calendar: calendar)
        }
    }

    /// The same, matched against `logs` instead of each medication's `logs`.
    static func pills(of courses: [TreatmentCourse], on day: Date, calendar: Calendar, logs: LogIndex) -> [PillDose] {
        pills(of: courses, on: day, calendar: calendar) { med in logs.bySlot(of: med.id) }
    }

    /// Logs read once for a range of days, by medication and slot. BackgroundReader
    /// fills it with a fetch by date: `medication.logs` faults in a medication's
    /// whole history, and walking it for every day costs more the longer the app is used.
    struct LogIndex {
        private var logs: [UUID: [DateComponents: DoseLog]] = [:]

        init(_ logs: [DoseLog], calendar: Calendar) {
            for log in logs {
                guard let medicationId = log.medication?.id else { continue }
                self.logs[medicationId, default: [:]][DoseSchedule.slotKey(log.scheduledTime, calendar: calendar)] = log
            }
        }

        /// Slot keys carry the day, so one dictionary serves every day in the range.
        func bySlot(of medicationId: UUID) -> [DateComponents: DoseLog] {
            logs[medicationId] ?? [:]
        }
    }

    private static func pills(
        of courses: [TreatmentCourse],
        on day: Date,
        calendar: Calendar,
        logsOf: (MedicationItem) -> [DateComponents: DoseLog]
    ) -> [PillDose] {
        var pills: [PillDose] = []

        for course in courses {
            for med in course.medications {
                let slots = DoseSchedule.slots(
                    for: med,
                    in: course,
                    on: day,
                    calendar: calendar
                )
                guard !slots.isEmpty else { continue }

                let logsBySlot = logsOf(med)

                for slot in slots {
                    let log = logsBySlot[DoseSchedule.slotKey(slot.date, calendar: calendar)]

                    pills.append(
                        PillDose(
                            medicationId: med.id,
                            name: med.name,
                            dosage: DoseSchedule.schedule(of: med, on: day).dosage,
                            form: med.form,
                            time: slot.date,
                            period: DayPeriod(hour: slot.hour),
                            status: log?.status ?? .pending,
                            stockCount: med.stockCount,
                            lowStockThreshold: med.lowStockThreshold,
                            courseId: course.id
                        )
                    )
                }
            }
        }

        return pills.sorted { $0.time < $1.time }
    }
}
