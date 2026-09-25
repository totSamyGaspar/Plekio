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
        var pills: [PillDose] = []

        for course in courses {
            let courseStart = calendar.startOfDay(for: course.startDate)
            let courseEnd = calendar.startOfDay(for: course.endDate)

            for med in course.medications {
                let slots = DoseSchedule.slots(
                    for: med,
                    courseStartDay: courseStart,
                    courseEndDay: courseEnd,
                    on: day,
                    calendar: calendar
                )
                guard !slots.isEmpty else { continue }

                let logsBySlot = DoseSchedule.logsBySlot(of: med, on: day, calendar: calendar)

                for slot in slots {
                    let log = logsBySlot[DoseSchedule.slotKey(slot.date, calendar: calendar)]

                    pills.append(
                        PillDose(
                            medicationId: med.id,
                            name: med.name,
                            dosage: DoseSchedule.schedule(of: med, on: day).dosage,
                            formSystemImage: med.formSystemImage,
                            time: slot.date,
                            period: DayPeriod(hour: slot.hour),
                            status: log?.status ?? .pending,
                            stockCount: med.stockCount,
                            lowStockThreshold: med.lowStockThreshold
                        )
                    )
                }
            }
        }

        return pills.sorted { $0.time < $1.time }
    }
}
