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
    @Environment(\.colorScheme) private var colorScheme

    private var style: BloodPressureStyle { BloodPressureStyle(colorScheme: colorScheme) }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
                    .containerBackground(for: .widget) {
                        if style.onHero {
                            HeroBackground(date: entry.date)
                        } else {
                            Color.widgetSurface
                        }
                    }
            } else {
                NeedsAppView()
                    .containerBackground(Color.widgetSurface, for: .widget)
            }
        }
        .widgetURL(WidgetLink.bloodPressureEntry.url)
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let readings = snapshot.bloodPressure ?? []
        if family == .systemMedium, readings.count > 1, let latest = readings.last {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    header(showsAddButton: false)
                    latestReading(latest)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)

                BloodPressureChart(readings: readings, style: style)
            }
        } else if let latest = readings.last {
            smallReading(latest)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                header()
                Spacer(minLength: 6)
                Text("Log a reading to see your pressure trend here.")
                    .font(.caption)
                    .foregroundStyle(style.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func smallReading(_ reading: WidgetSnapshot.Reading) -> some View {
        VStack(spacing: 0) {
            HStack {
                WidgetLogo(size: 16, tint: style.logo)
                Spacer(minLength: 4)
                addButton
            }

            VStack(spacing: 2) {
                Text(verbatim: "\(reading.systolic)/\(reading.diastolic)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(style.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(Text(verbatim: "\(reading.systolic)/\(reading.diastolic) ") + Text("mmHg"))
                if let pulse = reading.pulse {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.footnote)
                            .foregroundStyle(style.heart)
                            .accessibilityHidden(true)
                        Text("\(pulse) bpm")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(style.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            Spacer(minLength: 4)

            VStack(spacing: 1) {
                Text(reading.measuredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(style.tertiary)
                    .lineLimit(1)
                Text("Blood Pressure")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(style.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private var addButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(style.buttonInk)
            .frame(width: 24, height: 24)
            .background(style.button, in: Circle())
            .widgetAccentable()
            .accessibilityLabel(Text("Add reading"))
    }

    /// The title and the "+" that says what a tap does.
    private func header(showsAddButton: Bool = true) -> some View {
        HStack(spacing: 5) {
            WidgetLogo(size: 14, tint: style.logo)
            Text("Blood Pressure")
                .font(.caption.weight(.bold))
                .foregroundStyle(style.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if showsAddButton {
                addButton
            }
        }
    }

    private func latestReading(_ reading: WidgetSnapshot.Reading) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 4)
            Text(verbatim: "\(reading.systolic)/\(reading.diastolic)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(style.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(Text(verbatim: "\(reading.systolic)/\(reading.diastolic) ") + Text("mmHg"))
            if let pulse = reading.pulse {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(style.heart)
                        .accessibilityHidden(true)
                    Text("\(pulse) bpm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.secondary)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 4)
            Text(reading.measuredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                .font(.caption2)
                .foregroundStyle(style.tertiary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BloodPressureStyle {
    let onHero: Bool

    init(colorScheme: ColorScheme) {
        onHero = colorScheme == .light
    }

    var primary: Color { onHero ? .white : .textPrimary }
    var secondary: Color { onHero ? .white.opacity(0.85) : .textSecondary }
    var tertiary: Color { onHero ? .white.opacity(0.7) : .textTertiary }
    var heart: Color { onHero ? .heroHeart : .warningAccent }
    var logo: Color { onHero ? .white : .accentPrimary }
    var button: Color { onHero ? .white : .accentPrimary }
    var buttonInk: Color { onHero ? .onHeroButton : .onAccent }

    var systolic: Color { onHero ? .white : .accentPrimary }
    var diastolic: Color { onHero ? .white.opacity(0.6) : .warmAccent }
    var band: [Color] {
        onHero
            ? [.white.opacity(0.22), .white.opacity(0.08)]
            : [Color.warmAccent.opacity(0.18), Color.accentPrimary.opacity(0.14)]
    }
    var grid: Color { onHero ? .white.opacity(0.15) : Color.textPrimary.opacity(0.07) }
}
