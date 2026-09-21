//
//  BloodPressureCard.swift
//  Plekio
//

import SwiftUI
import Charts

/// Blood-pressure trend, the last reading, and the way into the full history.
///
/// Values are shown, never judged: no "normal / elevated" colouring anywhere.
/// Classifying a reading is a medical call that depends on age, medication and
/// how the measurement was taken, and a badge in a tracker would read as one.
///
/// The history lives in a sheet rather than inline, so the card stays a fixed
/// height whatever it holds — listed here, every new measurement pushes the rest
/// of the tab further down.
struct BloodPressureCard: View {
    let readings: [BloodPressureReading]
    var onAdd: () -> Void
    var onDelete: (BloodPressureReading) -> Void
    var onDeleteAll: () -> Void
    
    @State private var isHistoryShown = false
    
    /// Oldest first, so the chart reads left to right.
    private var chartReadings: [BloodPressureReading] {
        Array(readings.prefix(14)).sorted { $0.measuredAt < $1.measuredAt }
    }
    
    /// Not `readings.first`: the caller's sort order is its own business, and the
    /// headline number is wrong the moment that assumption stops holding.
    private var latestReading: BloodPressureReading? {
        readings.max { $0.measuredAt < $1.measuredAt }
    }
    
    /// The y-axis covers the readings, not zero.
    ///
    /// A blood-pressure axis anchored at 0 spends half its height on values a
    /// person cannot have, and flattens the variation that is the whole point of
    /// the chart. Rounded outwards to a multiple of ten so the gridlines land on
    /// readable numbers.
    private var yDomain: ClosedRange<Int> {
        let values = chartReadings.flatMap { [$0.systolic, $0.diastolic] }
        guard let lowest = values.min(), let highest = values.max() else {
            return 60...160
        }
        let lower = max(0, ((lowest - 15) / 10) * 10)
        let upper = ((highest + 15 + 9) / 10) * 10
        // A single reading, or several identical ones, would collapse the domain
        // to a point and the line would have nowhere to sit.
        return lower < upper ? lower...upper : lower...(lower + 40)
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
    
    /// Chart and legend sit together on the darker app background, the same inset
    /// panel the rest of the app uses inside a surface card. It gives the plot an
    /// edge to sit against instead of floating in the middle of the card.
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
        // The labels handed to .value are localizable too, so they reuse keys the
        // catalog already carries rather than adding untranslated stubs for
        // strings that never reach the screen — the legend is drawn by hand.
        Chart(chartReadings) { reading in
            // The gap between the two lines is the pulse pressure, so filling it
            // is not decoration: it is the one derived value a reader takes from
            // this chart at a glance.
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
            // Monotone rather than a spline: it smooths the corners without
            // inventing a peak higher than any reading actually taken.
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
            // Three dates at most: on a card this wide, four already collide in
            // the languages with long month abbreviations.
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: 170)
        // The chart is a picture; the tile below and the history sheet carry the
        // same numbers in a form VoiceOver can read one by one.
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
    
    /// History on the left, the primary action on the right: on a phone held in
    /// the right hand the trailing edge is the easiest place to reach, and adding
    /// a reading is what this card is opened for.
    private var actions: some View {
        HStack(spacing: 10) {
            // Hugs its own width rather than taking half the row: "Add reading"
            // is the longer label in every translation, and splitting the row
            // evenly is what would force it to shrink.
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
        }
    }
}
