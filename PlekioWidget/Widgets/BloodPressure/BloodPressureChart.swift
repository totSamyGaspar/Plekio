//
//  BloodPressureChart.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Charts
import SwiftUI
import WidgetKit

/// The diary card's chart, compact: systolic in the accent, diastolic in the warm
/// colour, the band between them shaded.
struct BloodPressureChart: View {
    let readings: [WidgetSnapshot.Reading]
    let style: BloodPressureStyle

    private var systolicColor: Color { style.systolic }
    private var diastolicColor: Color { style.diastolic }

    /// Fits the readings, rounded outward to tens, as on the diary card.
    private var yDomain: ClosedRange<Int> {
        let values = readings.flatMap { [$0.systolic, $0.diastolic] }
        guard let lowest = values.min(), let highest = values.max() else { return 60...160 }
        let lower = max(0, ((lowest - 15) / 10) * 10)
        let upper = ((highest + 15 + 9) / 10) * 10
        return lower < upper ? lower...upper : lower...(lower + 40)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart(readings) { reading in
                AreaMark(
                    x: .value("Measured at", reading.measuredAt),
                    yStart: .value("mmHg", reading.diastolic),
                    yEnd: .value("mmHg", reading.systolic)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: style.band,
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
                .foregroundStyle(systolicColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
                .symbol(.circle)
                .symbolSize(24)

                LineMark(
                    x: .value("Measured at", reading.measuredAt),
                    y: .value("mmHg", reading.diastolic),
                    series: .value("Blood Pressure", "diastolic")
                )
                .foregroundStyle(diastolicColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
                .symbol(.circle)
                .symbolSize(24)
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(style.grid)
                    AxisValueLabel()
                        .font(.system(size: 8))
                        .foregroundStyle(style.tertiary)
                }
            }

            HStack(spacing: 10) {
                legend(systolicColor, "Systolic")
                legend(diastolicColor, "Diastolic")
            }
        }
        // The latest reading beside it says it in words.
        .accessibilityHidden(true)
    }

    private func legend(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(style.secondary)
                .lineLimit(1)
        }
    }
}
