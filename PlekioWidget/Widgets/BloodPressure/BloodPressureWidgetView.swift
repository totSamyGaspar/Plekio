//
//  BloodPressureWidgetView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import Charts
import SwiftUI
import WidgetKit

/// The latest reading and, on the medium one, the trend of the last seven. Values
/// only, never "normal" or "high", as on the diary's card: that is a medical call.
/// A tap opens the entry form, as the daily blood-pressure reminder does; numbers
/// can't be typed into a widget.
struct BloodPressureWidgetView: View {
    let entry: DoseEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else {
                NeedsAppView()
            }
        }
        .containerBackground(Color.widgetSurface, for: .widget)
        .widgetURL(WidgetLink.bloodPressureEntry.url)
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let readings = snapshot.bloodPressure ?? []
        if family == .systemMedium, readings.count > 1, let latest = readings.last {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 6)
                    latestReading(latest)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)

                BloodPressureChart(readings: readings)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 6)
                if let latest = readings.last {
                    latestReading(latest)
                } else {
                    Text("Log a reading to see your pressure trend here.")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The title and the "+" that says what a tap does.
    private var header: some View {
        HStack(spacing: 5) {
            WidgetLogo(size: 14)
            Text("Blood Pressure")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.onAccent)
                .frame(width: 24, height: 24)
                .background(Color.accentPrimary, in: Circle())
                .widgetAccentable()
                .accessibilityLabel(Text("Add reading"))
        }
    }

    private func latestReading(_ reading: WidgetSnapshot.Reading) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "\(reading.systolic)/\(reading.diastolic)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("mmHg")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            if let pulse = reading.pulse {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.warningAccent)
                        .accessibilityHidden(true)
                    Text("\(pulse) bpm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Text(reading.measuredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
