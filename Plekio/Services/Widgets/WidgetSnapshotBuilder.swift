//
//  WidgetSnapshotBuilder.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - WidgetSnapshotBuilder

/// Turns the app's schedule into the widget's snapshot. Pure: the caller reads
/// the store, so this can be tested without one.
nonisolated enum WidgetSnapshotBuilder {

    /// - Parameters:
    ///   - pills: the schedule for today and tomorrow, as `fetchPills` returns it.
    ///   - lowStock: medications of active courses that are low, as on Today's refill card.
    static func build(
        pills: [PillDose],
        streakDays: Int,
        lowStock: [MedicationSnapshot],
        now: Date
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: now,
            missedGrace: DoseSchedule.missedGrace,
            slots: slots(from: pills),
            streakDays: streakDays,
            lowStock: lowStock
                .sorted { ($0.stockCount, $0.name) < ($1.stockCount, $1.name) }
                .map(stockAlert)
        )
    }

    // MARK: - Slots

    /// Grouped by exact time, not by minute like the hero card: the widget sends the
    /// slot back to `openDoses(medicationIds:at:)`, which matches within a second.
    /// Dose times come from minutes of the day, so the two groupings agree.
    static func slots(from pills: [PillDose]) -> [WidgetSnapshot.Slot] {
        Dictionary(grouping: pills, by: \.time)
            .map { time, group in
                WidgetSnapshot.Slot(
                    time: time,
                    period: period(group[0].period),
                    // By name, as the store's to-many relationships have no stable order.
                    doses: group.sorted { $0.name < $1.name }.map(dose)
                )
            }
            .sorted { $0.time < $1.time }
    }

    private static func dose(_ pill: PillDose) -> WidgetSnapshot.Dose {
        WidgetSnapshot.Dose(
            medicationId: pill.medicationId,
            name: pill.name,
            dosage: pill.dosage,
            form: form(pill.form),
            status: status(pill.status)
        )
    }

    private static func stockAlert(_ medication: MedicationSnapshot) -> WidgetSnapshot.StockAlert {
        WidgetSnapshot.StockAlert(
            medicationId: medication.id,
            name: medication.name,
            stock: medication.stockCount,
            threshold: medication.lowStockThreshold
        )
    }

    // MARK: - Mapping

    // Exhaustive switches: a new case in the app fails the build here instead of
    // reaching the widget as something it can't draw.

    static func period(_ period: DayPeriod) -> WidgetSnapshot.Period {
        switch period {
        case .morning: .morning
        case .noon: .afternoon
        case .evening: .evening
        }
    }

    static func form(_ form: MedicationForm) -> WidgetSnapshot.Form {
        switch form {
        case .pill: .pill
        case .capsule: .capsule
        case .drops: .drops
        case .injection: .injection
        }
    }

    static func status(_ status: DoseStatus) -> WidgetSnapshot.Status {
        switch status {
        case .pending: .pending
        case .taken: .taken
        case .skipped: .skipped
        }
    }
}
