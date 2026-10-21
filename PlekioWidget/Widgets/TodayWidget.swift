//
//  TodayWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - TodayWidget

struct TodayWidget: Widget {
    static let kind = "Today"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            TodayView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Every dose of the day, morning to evening.")
        .supportedFamilies([.systemLarge])
        // The up-next card runs to the widget's edges; TodayView pads the rest itself.
        .contentMarginsDisabled()
    }
}

// MARK: - TodayView

/// The Today screen in one card: the up-next block, then the day by slot.
struct TodayView: View {
    let entry: DoseEntry

    /// Room for about four slot rows next to the hero block.
    private static let maxRows = 4

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
    }

    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let slots = snapshot.slotsOnDay(of: entry.date, calendar: entry.calendar)
        // Keep the rows around now: past settled slots go first when the list is long.
        let shown = Array(slots.suffix(from: max(0, slots.count - Self.maxRows)))

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

            VStack(alignment: .leading, spacing: 10) {
                rows(shown, in: snapshot)
                Spacer(minLength: 0)
                footer(snapshot)
            }
            .padding(.horizontal, Self.margin)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
    }

    private func rows(_ shown: [WidgetSnapshot.Slot], in snapshot: WidgetSnapshot) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, slot in
                // A divider only between plain rows: a missed row's wash already sets it apart.
                if index > 0, !isMissed(shown[index - 1], in: snapshot), !isMissed(slot, in: snapshot) {
                    Divider()
                }
                SlotRow(slot: slot, snapshot: snapshot, now: entry.date)
            }
        }
    }

    private func isMissed(_ slot: WidgetSnapshot.Slot, in snapshot: WidgetSnapshot) -> Bool {
        slot.doses.contains { snapshot.isMissed($0, in: slot, at: entry.date) }
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

// MARK: - SlotRow

/// One time of day: period, time, medications and how far it got.
struct SlotRow: View {
    let slot: WidgetSnapshot.Slot
    let snapshot: WidgetSnapshot
    let now: Date

    private var pending: [WidgetSnapshot.Dose] { slot.doses.filter { $0.status == .pending } }
    private var isMissed: Bool { !pending.isEmpty && snapshot.isMissed(pending[0], in: slot, at: now) }
    private var isSettled: Bool { pending.isEmpty }

    var body: some View {
        HStack(spacing: 10) {
            Text(slot.period.title)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            slot.time.widgetTime
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.textPrimary)

            Text(slot.doses.map(\.name).formatted(.list(type: .and, width: .narrow)))
                .font(.subheadline)
                .foregroundStyle(isSettled ? Color.textSecondary : Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .frame(height: 34)
        .padding(.horizontal, isMissed ? 8 : 0)
        .background {
            if isMissed {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.missedWash)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isSettled {
            DoseMark(status: slot.doses.contains { $0.status == .taken } ? .taken : .skipped, size: 22)
        } else {
            HStack(spacing: 6) {
                if isMissed {
                    Text("MISSED")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Color.warningAccent)
                } else if pending.count < slot.doses.count {
                    // Partly logged: how far it got, next to the button that finishes it.
                    Text(verbatim: "\(slot.doses.count - pending.count)/\(slot.doses.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                        .invalidatableContent()
                }
                // Logs the slot's open doses, like the checkmark on Today; missed ones included.
                Button(intent: slot.takeOpenDoses) {
                    DoseMark(status: .pending, isMissed: isMissed, size: 22)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(pending.count > 1 ? "Take All" : "Take Now"))
            }
        }
    }
}
