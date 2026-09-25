//
//  BloodPressureCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.08.2026.
//

import SwiftUI
import Charts

/// Blood-pressure trend, latest reading and history entry point. Values are
/// never classified (no "normal/elevated" colouring): that is a medical call.
struct BloodPressureCard: View {

    // MARK: - Properties

    let readings: [BloodPressureSnapshot]
    /// Both buttons zoom into their sheets; "Add reading" is presented by the parent.
    let transitions: Namespace.ID
    var onAdd: () -> Void
    var onDelete: (BloodPressureSnapshot) -> Void
    var onDeleteAll: () -> Void

    @State private var isHistoryShown = false

    static let addSourceID = "diary.bloodPressure.add"
    private static let historySourceID = "diary.bloodPressure.history"

    // MARK: - Derived state

    /// Oldest first, so the chart reads left to right.
    private var chartReadings: [BloodPressureSnapshot] {
        Array(readings.prefix(14)).sorted { $0.measuredAt < $1.measuredAt }
    }

    /// Computed by date; doesn't rely on the caller's sort order.
    private var latestReading: BloodPressureSnapshot? {
        readings.max { $0.measuredAt < $1.measuredAt }
    }

    /// Fits the readings (not anchored at zero), rounded outward to tens.
    private var yDomain: ClosedRange<Int> {
        let values = chartReadings.flatMap { [$0.systolic, $0.diastolic] }
        guard let lowest = values.min(), let highest = values.max() else {
            return 60...160
        }
        let lower = max(0, ((lowest - 15) / 10) * 10)
        let upper = ((highest + 15 + 9) / 10) * 10
        // Avoid a zero-height domain when all readings are identical.
        return lower < upper ? lower...upper : lower...(lower + 40)
    }

    // MARK: - Body

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
                chartPanel
                latestTile
            }

            actions
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
        .sheet(isPresented: $isHistoryShown) {
            BloodPressureHistoryView(
                readings: readings,
                onDelete: onDelete,
                onDeleteAll: onDeleteAll
            )
            .navigationTransition(.zoom(sourceID: Self.historySourceID, in: transitions))
        }
    }

    // MARK: - Header

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

    // MARK: - Chart

    /// Chart and legend on an inset app-background panel.
    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            chart
            legend
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color.appBackground)
        .cornerRadius(16)
    }

    private var chart: some View {
        // .value labels are localizable; reuse existing catalog keys.
        Chart(chartReadings) { reading in
            // Fill between lines shows pulse pressure.
            AreaMark(
                x: .value("Measured at", reading.measuredAt),
                yStart: .value("mmHg", reading.diastolic),
                yEnd: .value("mmHg", reading.systolic)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.warmAccent.opacity(0.18), Color.accentPrimary.opacity(0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Measured at", reading.measuredAt),
                y: .value("mmHg", reading.systolic),
                series: .value("Blood Pressure", "systolic")
            )
            .foregroundStyle(Color.accentPrimary)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            // Monotone: smooth without overshooting real readings.
            .interpolationMethod(.monotone)
            .symbol(.circle)
            .symbolSize(46)

            LineMark(
                x: .value("Measured at", reading.measuredAt),
                y: .value("mmHg", reading.diastolic),
                series: .value("Blood Pressure", "diastolic")
            )
            .foregroundStyle(Color.warmAccent)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
            .symbol(.circle)
            .symbolSize(46)
        }
        .chartLegend(.hidden)
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.textPrimary.opacity(0.07))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .chartXAxis {
            // Max three dates: long month abbreviations collide otherwise.
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: 170)
        // VoiceOver reads the tile and history sheet instead.
        .accessibilityHidden(true)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .accentPrimary, title: "Systolic")
            legendItem(color: .warmAccent, title: "Diastolic")
            Spacer(minLength: 0)
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

    // MARK: - Latest reading

    @ViewBuilder
    private var latestTile: some View {
        if let reading = latestReading {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Latest")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.textTertiary)
                        .textCase(.uppercase)
                    Text(reading.formattedPressure)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.textPrimary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    if let pulse = reading.pulse {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.warningAccent)
                            Text("\(pulse) bpm")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    Text(reading.measuredAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.appBackground)
            .cornerRadius(16)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Actions

    /// Primary "Add reading" on the trailing edge for easier reach.
    private var actions: some View {
        HStack(spacing: 10) {
            // Hugs its width so the longer "Add reading" label gets the rest.
            Button {
                isHistoryShown = true
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.centered)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.accentPrimary)
                    .lineLimit(1)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentPrimary.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.accentPrimary.opacity(0.30), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: Self.historySourceID, in: transitions)
            .disabled(readings.isEmpty)
            .opacity(readings.isEmpty ? 0.4 : 1)
            .accessibilityLabel("Measurement history")

            Button(action: onAdd) {
                Label("Add reading", systemImage: "plus")
                    .labelStyle(.centered)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.onAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentPrimary)
                    .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: Self.addSourceID, in: transitions)
        }
    }
}
