//
//  DayProgressWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// MARK: - DayProgressWidget

struct DayProgressWidget: Widget {
    static let kind = "DayProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            DayProgressView(entry: entry)
        }
        .configurationDisplayName("Day progress")
        .description("How much of today's plan is logged.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - DayProgressView

struct DayProgressView: View {
    let entry: DoseEntry

    @Environment(\.widgetFamily) private var family

    private var progress: (taken: Int, total: Int) {
        entry.snapshot?.progress(onDayOf: entry.date, calendar: entry.calendar) ?? (0, 0)
    }

    private var fraction: Double {
        progress.total > 0 ? Double(progress.taken) / Double(progress.total) : 0
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .accessoryCircular { Color.clear } else { Color.widgetSurface }
            }
            .widgetURL(WidgetLink.today.url)
    }

    @ViewBuilder
    private var content: some View {
        switch (family, entry.state) {
        case (.accessoryCircular, .needsApp):
            circular(label: Text(verbatim: "–"))
        case (.accessoryCircular, _):
            circular(label: Text(verbatim: "\(progress.taken)/\(progress.total)"))
        case (_, .needsApp):
            NeedsAppView()
        case (_, .empty):
            EmptyDayView(tomorrow: entry.snapshot?.firstSlot(afterDayOf: entry.date, calendar: entry.calendar))
        case (_, .ready(let snapshot)):
            small(snapshot)
        }
    }

    // MARK: Small

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                WidgetLogo(size: 14)
                Text("Today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textSecondary)
                Spacer(minLength: 4)
                if let next = snapshot.upNext(at: entry.date, calendar: entry.calendar) {
                    next.time.widgetTime
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.accentPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentPrimary.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                }
            }

            ZStack {
                ProgressRing(progress: fraction, lineWidth: 9)
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.widgetSerif(18, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
            }
            .frame(maxHeight: .infinity)
            .padding(.vertical, 4)

            HStack(spacing: 4) {
                Text("Taken")
                Text(verbatim: "\(progress.taken)/\(progress.total)")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
            }
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: Lock Screen

    private func circular(label: Text) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            ProgressRing(progress: fraction, lineWidth: 5, track: .white.opacity(0.3), ring: [.white, .white])
            VStack(spacing: 1) {
                WidgetLogo(size: 10, tint: .white)
                label
                    .font(.widgetSerif(13))
                    .minimumScaleFactor(0.6)
            }
            .padding(9)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(progress.taken) of \(progress.total) doses logged"))
    }
}
