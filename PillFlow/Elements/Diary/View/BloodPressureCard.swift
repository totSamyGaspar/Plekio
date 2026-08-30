//
//  BloodPressureCard.swift
//  PillFlow
//

import SwiftUI
import Charts

/// Blood-pressure trend and the most recent readings.
///
/// Values are shown, never judged: no "normal / elevated" colouring anywhere.
/// Classifying a reading is a medical call that depends on age, medication and
/// how the measurement was taken, and a badge in a tracker would read as one.
struct BloodPressureCard: View {
    let readings: [BloodPressureReading]
    var onAdd: () -> Void
    var onDelete: (BloodPressureReading) -> Void

    /// Oldest first, so the chart reads left to right; the list below wants the
    /// opposite order and reverses it back.
    private var chartReadings: [BloodPressureReading] {
        Array(readings.prefix(14)).sorted { $0.measuredAt < $1.measuredAt }
    }

    private var recentReadings: [BloodPressureReading] {
        Array(readings.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if chartReadings.isEmpty {
                Text("Log a reading to see your pressure trend here.")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                chart
                legend
                Divider().opacity(0.15)
                ForEach(recentReadings) { reading in
                    row(reading)
                }
            }

            Button(action: onAdd) {
                Label("Add reading", systemImage: "plus")
                    .labelStyle(.centered)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.onAccent)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentPrimary)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Blood Pressure")
                .scaledFont(size: 18, relativeTo: .headline, weight: .bold, design: .serif)
                .foregroundColor(.textPrimary)
            Text("Systolic and diastolic over time")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }

    private var chart: some View {
        // The labels handed to .value are localizable too, so they reuse keys the
        // catalog already carries rather than adding untranslated stubs for
        // strings that never reach the screen — the legend is drawn by hand.
        Chart(chartReadings) { reading in
            LineMark(
                x: .value("Measured at", reading.measuredAt),
                y: .value("mmHg", reading.systolic),
                series: .value("Blood Pressure", "systolic")
            )
            .foregroundStyle(Color.accentPrimary)
            .symbol(.circle)

            LineMark(
                x: .value("Measured at", reading.measuredAt),
                y: .value("mmHg", reading.diastolic),
                series: .value("Blood Pressure", "diastolic")
            )
            .foregroundStyle(Color.warmAccent)
            .symbol(.circle)
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.textPrimary.opacity(0.08))
                AxisValueLabel().foregroundStyle(Color.textSecondary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(height: 180)
        // The chart is a picture; the rows underneath carry the same numbers in
        // a form VoiceOver can read one by one.
        .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .accentPrimary, title: "Systolic")
            legendItem(color: .warmAccent, title: "Diastolic")
            Spacer()
        }
        .accessibilityHidden(true)
    }

    private func legendItem(color: Color, title: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.textSecondary)
        }
    }

    private func row(_ reading: BloodPressureReading) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reading.formattedPressure)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.textPrimary)
                Text(reading.measuredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if let pulse = reading.pulse {
                Text("\(pulse) bpm")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.textSecondary)
            }

            Button {
                onDelete(reading)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.warningAccent)
            }
            .buttonStyle(.plain)
            .expandTouchTarget(vertical: 12, horizontal: 8)
            .accessibilityLabel("Delete reading")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
