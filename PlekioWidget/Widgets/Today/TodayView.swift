//
//  TodayView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

/// The Today screen in one card: the up-next block, then the day by slot.
struct TodayView: View {
    let entry: DoseEntry

    /// Content margins are off for the edge-to-edge card; this stands in for them.
    private static let margin: CGFloat = 16

    var body: some View {
        Group {
            switch entry.state {
            case .needsApp:
                NeedsAppView().padding(Self.margin)
            case .empty:
                EmptyDayView(tomorrow: entry.snapshot?.firstSlot(afterDayOf: entry.date, calendar: entry.calendar))
                    .padding(Self.margin)
            case .ready(let snapshot):
                content(snapshot)
            }
        }
        .containerBackground(Color.widgetSurface, for: .widget)
        // Checks log in place; anywhere else opens Today.
        .widgetURL(WidgetLink.today.url)
    }

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let slots = snapshot.slotsOnDay(of: entry.date, calendar: entry.calendar)
        let card = UpNextCard(entry: entry, isMedium: true)

        return VStack(alignment: .leading, spacing: 0) {
            // No frame of its own: the widget's corners round it.
            card
                .padding(.horizontal, Self.margin)
                .padding(.top, Self.margin)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .top)
                .background { card.background }
                // Whatever doesn't fit stays inside the card instead of running over the rows.
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                // The list gets whatever height this widget size leaves, and fills it.
                GeometryReader { geometry in
                    let lines = DayLine.lines(for: slots, in: snapshot, at: entry.date, height: geometry.size.height)
                    VStack(alignment: .leading, spacing: DayLine.spacing) {
                        ForEach(lines) { line in
                            DayLineView(line: line, snapshot: snapshot, now: entry.date)
                        }
                    }
                }
                footer(snapshot)
            }
            .padding(.horizontal, Self.margin)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func footer(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 8) {
            // A finished day already shows the streak on the card above.
            if snapshot.streakDays > 0, !snapshot.isDayComplete(at: entry.date, calendar: entry.calendar) {
                Label {
                    Text("\(snapshot.streakDays) days streak!")
                } icon: {
                    Image(systemName: "flame.fill").foregroundStyle(Color.warmAccent)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.textPrimary)
            }
            Spacer(minLength: 4)
            if let low = snapshot.lowStock.first {
                Label {
                    Text(verbatim: low.name) + Text(verbatim: " · ") + Text("Stock: \(low.stock)")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.warningAmber)
                .lineLimit(1)
            }
        }
    }
}
