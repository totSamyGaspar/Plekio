//
//  UpNextWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - UpNext

/// What the "Up next" widget shows at one moment. The order matches Today: the
/// next open slot first; a missed one only when nothing is ahead; then the day's summary.
enum UpNext {
    case next(WidgetSnapshot.Slot)
    case missed(WidgetSnapshot.Slot)
    case complete
    case empty(tomorrow: WidgetSnapshot.Slot?)
    case needsApp

    init(_ entry: DoseEntry) {
        switch entry.state {
        case .needsApp:
            self = .needsApp
        case .empty:
            self = .empty(tomorrow: entry.snapshot?.firstSlot(afterDayOf: entry.date, calendar: entry.calendar))
        case .ready(let snapshot):
            if let next = snapshot.upNext(at: entry.date, calendar: entry.calendar) {
                self = .next(next)
            } else if let missed = snapshot.missed(at: entry.date, calendar: entry.calendar).first {
                self = .missed(missed)
            } else {
                self = .complete
            }
        }
    }
}

// MARK: - UpNextWidget

struct UpNextWidget: Widget {
    static let kind = "UpNext"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            UpNextView(entry: entry)
        }
        .configurationDisplayName("Up next")
        .description("Your next doses, ready to log.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - UpNextView

struct UpNextView: View {
    let entry: DoseEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        // The Lock Screen draws its own backdrop; WidgetKit still expects a container background.
        case .accessoryRectangular:
            UpNextRectangular(entry: entry).containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            UpNextInline(entry: entry).containerBackground(for: .widget) { Color.clear }
        default:
            let card = UpNextCard(entry: entry, isMedium: family == .systemMedium)
            card.containerBackground(for: .widget) { card.background }
        }
    }
}

// MARK: - Home Screen

/// Small and medium share one layout; medium lists the doses with their dosage.
/// The Today widget embeds it, so its background is a property, not set here.
struct UpNextCard: View {
    let entry: DoseEntry
    let isMedium: Bool

    private var snapshot: WidgetSnapshot? { entry.snapshot }
    private var dayProgress: (taken: Int, total: Int) {
        snapshot?.progress(onDayOf: entry.date, calendar: entry.calendar) ?? (0, 0)
    }

    /// Hero gradient for the next slot and the finished day, a missed wash, else the card colour.
    @ViewBuilder
    var background: some View {
        switch UpNext(entry) {
        case .next, .complete:
            HeroBackground(date: entry.date)
        case .missed:
            ZStack {
                Color.widgetSurface
                Color.missedWash
            }
        case .empty, .needsApp:
            Color.widgetSurface
        }
    }

    var body: some View {
        switch UpNext(entry) {
        case .next(let slot): next(slot)
        case .missed(let slot): missed(slot)
        case .complete: complete
        case .empty(let tomorrow): EmptyDayView(tomorrow: tomorrow)
        case .needsApp: NeedsAppView()
        }
    }

    // MARK: Next

    private func next(_ slot: WidgetSnapshot.Slot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                // Not on the small one: the chip and the time already fill its top row.
                if isMedium { WidgetLogo(size: 18, tint: .white) }
                HeroChip(title: isMedium ? "UP NEXT TODAY" : slot.period.title)
                    .textCase(.uppercase)
                Spacer(minLength: 4)
                slot.time.widgetTime
                    .font(.system(size: isMedium ? 24 : 22, weight: .bold))
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)
            DoseNames(doses: slot.doses, limit: 2, onHero: true, showsDosage: isMedium, slot: slot)
            Spacer(minLength: 6)

            HStack(alignment: .center) {
                if isMedium {
                    Text("\(dayProgress.taken) of \(dayProgress.total) doses logged")
                        .font(.caption)
                        .opacity(0.88)
                        .invalidatableContent()
                } else {
                    Text(verbatim: "\(slot.doses.filter { $0.status == .taken }.count)/\(slot.doses.count)")
                        .font(.caption.weight(.semibold))
                        .opacity(0.88)
                        .invalidatableContent()
                }
                Spacer(minLength: 4)
                // Off: the slot shown here is still open. Tapped, it turns to a check at once.
                if isMedium {
                    Toggle(isOn: false, intent: slot.takeOpenDoses) { EmptyView() }
                        .toggleStyle(HeroPillToggleStyle(title: slot.doses.count > 1 ? "LOG ALL" : "LOG NOW"))
                } else {
                    Toggle(isOn: false, intent: slot.takeOpenDoses) { EmptyView() }
                        .toggleStyle(HeroCheckToggleStyle(label: slot.doses.count > 1 ? "Take All" : "Take Now"))
                }
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: Missed

    private func missed(_ slot: WidgetSnapshot.Slot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if isMedium { WidgetLogo(size: 16) }
                Text("MISSED")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.warningAccent)
                Spacer(minLength: 4)
                slot.time.widgetTime
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 6)
            DoseNames(doses: slot.doses.filter { $0.status == .pending }, limit: 2,
                      onHero: false, showsDosage: isMedium, isMissed: true, slot: slot)
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                // Late doses still count, as on Today: the checkmark stays live past the grace.
                Toggle(isOn: false, intent: slot.takeOpenDoses) { EmptyView() }
                    .toggleStyle(MissedTakeToggleStyle(title: slot.doses.count > 1 ? "Take All" : "Take Now"))

                // A deliberate skip, so the slot stops counting as missed.
                Button(intent: slot.skipOpenDoses) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 30)
                        .background(Color.textPrimary.opacity(0.07), in: Capsule())
                        .accessibilityLabel(Text("Skip"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Complete

    private var complete: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if isMedium { WidgetLogo(size: 18, tint: .white) }
                HeroChip(title: "ALL DONE TODAY", systemImage: "checkmark")
                Spacer(minLength: 0)
            }
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: isMedium ? 22 : 18, weight: .bold))
                    .widgetAccentable()
                Text("Day complete")
                    .font(.widgetSerif(isMedium ? 24 : 18))
                    .lineLimit(isMedium ? 1 : 2)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 6)
            if isMedium {
                HStack {
                    Text("\(dayProgress.taken) of \(dayProgress.total) doses logged")
                        .font(.caption)
                        .opacity(0.88)
                    Spacer(minLength: 4)
                    streak
                }
            } else {
                streak
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var streak: some View {
        if let days = snapshot?.streakDays, days > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(days) days streak!")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption.weight(.bold))
        } else {
            Text("Keep it up tomorrow")
                .font(.caption)
                .opacity(0.88)
        }
    }
}

// MARK: - DoseNames

/// The slot's medications, as on the hero card: a mark and the serif name.
/// At most `limit` lines: the rest is counted at the end of the last one, so a
/// long slot never pushes the card's bottom row out of the widget.
struct DoseNames: View {
    let doses: [WidgetSnapshot.Dose]
    let limit: Int
    let onHero: Bool
    var showsDosage = false
    var isMissed = false
    /// When set, a row's mark logs or un-logs that dose. Nil on cards without controls.
    var slot: WidgetSnapshot.Slot? = nil

    private var shown: [WidgetSnapshot.Dose] { Array(doses.prefix(limit)) }
    private var hidden: Int { doses.count - shown.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, dose in
                // Taken or open: a toggle, so the tap shows at once. A skip stays as it is.
                if let slot, dose.status != .skipped {
                    Toggle(isOn: dose.status == .taken, intent: slot.toggle(dose)) {
                        label(dose, index: index)
                    }
                    .toggleStyle(DoseRowToggleStyle(isMissed: isMissed, onHero: onHero))
                    .foregroundStyle(onHero ? Color.white : Color.textPrimary)
                    .accessibilityLabel(Text(dose.status == .taken ? "Undo logging \(dose.name)" : "Log \(dose.name)"))
                } else {
                    row(dose, index: index)
                }
            }
        }
    }

    private func row(_ dose: WidgetSnapshot.Dose, index: Int) -> some View {
        HStack(spacing: 7) {
            DoseMark(status: dose.status, isMissed: isMissed, onHero: onHero, size: 15)
            label(dose, index: index)
                .strikethrough(dose.status == .taken)
                .opacity(dose.status.isSettled ? 0.6 : 1)
        }
        .foregroundStyle(onHero ? Color.white : Color.textPrimary)
    }

    /// Name, dosage and how many more: what the mark sits next to.
    private func label(_ dose: WidgetSnapshot.Dose, index: Int) -> some View {
        HStack(spacing: 7) {
            Text(dose.name)
                .font(.widgetSerif(doses.count > 1 || showsDosage ? 16 : 19))
                .lineLimit(1)
            if showsDosage {
                Text("\(dose.dosage) pcs")
                    .font(.caption2)
                    .opacity(0.8)
                    .fixedSize()
            }
            if index == shown.count - 1, hidden > 0 {
                Text("\(hidden) more")
                    .font(.caption2.weight(.semibold))
                    .opacity(0.8)
                    .fixedSize()
            }
        }
    }
}

// MARK: - Lock Screen

struct UpNextRectangular: View {
    let entry: DoseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            switch UpNext(entry) {
            case .next(let slot):
                header { slot.time.widgetTime }
                names(slot.doses)
            case .missed(let slot):
                HStack(spacing: 4) {
                    WidgetLogo(size: 12)
                    Text("Missed")
                    Text(verbatim: "·")
                    slot.time.widgetTime
                }
                .font(.caption.weight(.heavy))
                names(slot.doses.filter { $0.status == .pending })
            case .complete:
                header { EmptyView() }
                Text("Day complete").font(.widgetSerif(16))
                if let days = entry.snapshot?.streakDays, days > 0 {
                    Text("\(days) days streak!").font(.caption)
                }
            case .empty(let tomorrow):
                header { EmptyView() }
                Text("Nothing for today").font(.headline)
                if let tomorrow {
                    HStack(spacing: 4) {
                        Text("Tomorrow")
                        tomorrow.time.widgetTime
                    }
                    .font(.caption)
                }
            case .needsApp:
                WidgetLogo(size: 14)
                Text("Open Plekio to update").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func header<Trailing: View>(@ViewBuilder _ trailing: () -> Trailing) -> some View {
        HStack(spacing: 4) {
            WidgetLogo(size: 12)
            Text("Up next")
            trailing()
        }
        .font(.caption.weight(.heavy))
        .textCase(.uppercase)
        .widgetAccentable()
    }

    private func names(_ doses: [WidgetSnapshot.Dose]) -> some View {
        Group {
            Text(doses.first?.name ?? "")
                .font(.widgetSerif(16))
                .lineLimit(1)
            if doses.count > 1 {
                Text("\(doses.count - 1) more")
                    .font(.caption)
            }
        }
    }
}

struct UpNextInline: View {
    let entry: DoseEntry

    var body: some View {
        // One line of system-styled text; images other than SF Symbols are dropped here.
        switch UpNext(entry) {
        case .next(let slot), .missed(let slot):
            Label {
                // Concatenated, not interpolated: the name and time aren't text to translate.
                slot.time.widgetTime + Text(verbatim: " · \(slot.doses.first?.name ?? "")")
            } icon: {
                Image(systemName: "pills.fill")
            }
        case .complete:
            Label("Day complete", systemImage: "checkmark.seal.fill")
        case .empty:
            Text("Nothing for today")
        case .needsApp:
            Text("Open Plekio to update")
        }
    }
}
