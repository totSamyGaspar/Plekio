//
//  DayProgressView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

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
                WidgetLogo(size: 16)
                Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
        // One stop for VoiceOver: "Today, 20:00, 60 %, Taken 3/5".
        .accessibilityElement(children: .combine)
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
