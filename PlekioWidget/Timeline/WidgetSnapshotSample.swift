//
//  WidgetSnapshotSample.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

/// Doses for the widget gallery, the placeholder and previews. Not DEBUG-only:
/// the gallery shows it in release builds too.
extension WidgetSnapshot {

    /// Morning taken, afternoon up next, evening ahead, tomorrow's morning.
    static func sample(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> WidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        func at(_ hour: Int, day: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: day, to: today) ?? today
            return calendar.date(byAdding: .hour, value: hour, to: base) ?? base
        }
        func dose(_ name: String, _ form: Form, _ status: Status = .pending, dosage: Int = 1) -> Dose {
            Dose(medicationId: UUID(), name: name, dosage: dosage, form: form, status: status)
        }

        // Systolic, diastolic, pulse for the last seven mornings; one without a pulse.
        let pressures: [(Int, Int, Int?)] = [
            (124, 82, 72), (128, 84, 75), (121, 79, nil), (126, 83, 70),
            (130, 86, 78), (123, 80, 71), (127, 82, 73)
        ]

        return WidgetSnapshot(
            generatedAt: now,
            missedGrace: 3600,
            slots: [
                Slot(time: at(8), period: .morning, doses: [dose("Vitamin D3", .capsule, .taken), dose("Sertraline", .pill, .taken)]),
                Slot(time: at(14), period: .afternoon, doses: [dose("Folic Acid", .pill)]),
                Slot(time: at(20), period: .evening, doses: [dose("Magnesium B6", .pill, dosage: 2), dose("Omega-3", .capsule)]),
                Slot(time: at(8, day: 1), period: .morning, doses: [dose("Vitamin D3", .capsule), dose("Sertraline", .pill)])
            ],
            streakDays: 12,
            lowStock: [StockAlert(medicationId: UUID(), name: "Sertraline", stock: 4, threshold: 10)],
            // No check-in yet: the gallery shows the diary's mood buttons.
            diary: nil,
            bloodPressure: pressures
                .enumerated()
                .map { index, values in
                    Reading(measuredAt: at(8, day: index - 6), systolic: values.0, diastolic: values.1, pulse: values.2)
                }
        )
    }
}
