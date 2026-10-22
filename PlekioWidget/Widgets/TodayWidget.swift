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

// MARK: - DayLine

/// One line of the day under the card: a time-of-day heading, a medication, or
/// how many more didn't fit. Laid out like Today's timeline, a dose per line.
enum DayLine: Identifiable {
    case period(WidgetSnapshot.Period, slot: Date)
    case dose(WidgetSnapshot.Dose, slot: WidgetSnapshot.Slot)
    case more(Int)

    var id: String {
        switch self {
        case .period(let period, let slot): "period-\(period.rawValue)-\(slot.timeIntervalSince1970)"
        case .dose(let dose, let slot): "dose-\(dose.medicationId)-\(slot.time.timeIntervalSince1970)"
        case .more: "more"
        }
    }

    static let spacing: CGFloat = 4
    private static let headingHeight: CGFloat = 16
    static let doseHeight: CGFloat = 28
    private static let moreHeight: CGFloat = 14

    private var height: CGFloat {
        switch self {
        case .period: Self.headingHeight
        case .dose: Self.doseHeight
        case .more: Self.moreHeight
        }
    }

    /// The lines that fit `height`, around now. They start at the first slot with
    /// something still open (missed ones included), reach back to earlier slots
    /// while the whole rest of the day still fits, and end with "N more" when it doesn't.
    static func lines(for slots: [WidgetSnapshot.Slot], in snapshot: WidgetSnapshot,
                      at now: Date, height: CGFloat) -> [DayLine] {
        guard !slots.isEmpty else { return [] }
        let firstOpen = slots.firstIndex { slot in slot.doses.contains { $0.status == .pending } } ?? slots.count - 1

        var best = fill(slots[firstOpen...], height: height)
        var start = firstOpen
        while best.fitsAll, start > 0 {
            let earlier = fill(slots[(start - 1)...], height: height)
            guard earlier.fitsAll else { break }
            best = earlier
            start -= 1
        }
        return best.lines
    }

    /// Lines from these slots on, a heading where the time of day changes.
    private static func fill(_ slots: ArraySlice<WidgetSnapshot.Slot>, height: CGFloat) -> (lines: [DayLine], fitsAll: Bool) {
        let doses = slots.flatMap { slot in slot.doses.map { (slot, $0) } }
        var lines: [DayLine] = []
        var used: CGFloat = 0
        var period: WidgetSnapshot.Period?

        for (index, (slot, dose)) in doses.enumerated() {
            var next: [DayLine] = []
            if slot.period != period { next.append(.period(slot.period, slot: slot.time)) }
            next.append(.dose(dose, slot: slot))

            let cost = next.reduce(0) { $0 + $1.height + spacing }
            let left = doses.count - index - 1
            // Keep room for "N more" unless this is the last dose.
            let reserve = left > 0 ? moreHeight + spacing : 0
            guard used + cost + reserve <= height + spacing else {
                lines.append(.more(doses.count - index))
                return (lines, false)
            }
            lines += next
            used += cost
            period = slot.period
        }
        return (lines, true)
    }
}

// MARK: - DayLineView

struct DayLineView: View {
    let line: DayLine
    let snapshot: WidgetSnapshot
    let now: Date

    var body: some View {
        switch line {
        case .period(let period, _):
            Text(period.title)
                .font(.system(size: 10, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Color.textSecondary)
                .frame(height: 16, alignment: .bottomLeading)
                // VoiceOver can jump between times of day with the rotor.
                .accessibilityAddTraits(.isHeader)
        case .dose(let dose, let slot):
            DoseLine(dose: dose, slot: slot, isMissed: snapshot.isMissed(dose, in: slot, at: now))
        case .more(let count):
            Text("\(count) more")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(height: 14, alignment: .leading)
        }
    }
}

// MARK: - DoseLine

/// A medication as on Today's cards: form tile, name, time and its mark.
/// Taken is struck through; skipped and missed get a wash and a label.
struct DoseLine: View {
    let dose: WidgetSnapshot.Dose
    let slot: WidgetSnapshot.Slot
    let isMissed: Bool

    private var wash: Color? {
        if isMissed { return .missedWash }
        if dose.status == .skipped { return .skippedWash }
        return nil
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentPrimary.opacity(0.14))
                Image(systemName: dose.form.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
                    .widgetAccentable()
            }
            .frame(width: 26, height: 26)
            .opacity(dose.status.isSettled ? 0.6 : 1)
            // The form is a picture of the name next to it; VoiceOver would read "pills.fill".
            .accessibilityHidden(true)

            Text(dose.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(dose.status.isSettled ? Color.textSecondary : Color.textPrimary)
                .strikethrough(dose.status == .taken)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .frame(height: DayLine.doseHeight)
        // The wash reaches 6 pt past the row, so a missed or skipped line stays in
        // line with the others instead of being pushed in by its own padding.
        .background {
            if let wash {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(wash)
                    .padding(.horizontal, -6)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch dose.status {
        case .taken:
            timeChip
            check
        case .skipped:
            label("SKIPPED", color: .textSecondary)
            DoseMark(status: .skipped, size: 22)
        case .pending:
            if isMissed {
                label("MISSED", color: .warningAccent)
            } else {
                timeChip
            }
            check
        }
    }

    /// Logs or un-logs this one medication, like its checkbox on Today; late ones
    /// included. A toggle, so the check shows the moment it's tapped.
    private var check: some View {
        Toggle(isOn: dose.status == .taken, intent: slot.toggle(dose)) { EmptyView() }
            .toggleStyle(DoseCheckToggleStyle(isMissed: isMissed, size: 22))
            .accessibilityLabel(Text(dose.status == .taken ? "Undo logging \(dose.name)" : "Log \(dose.name)"))
    }

    private var timeChip: some View {
        slot.time.widgetTime
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(Color.accentPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.accentPrimary.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .widgetAccentable()
    }

    private func label(_ key: LocalizedStringKey, color: Color) -> some View {
        Text(key)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }
}
