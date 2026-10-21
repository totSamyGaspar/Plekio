//
//  UpNextWidget.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

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
            HStack(alignment: .center) {
                HeroChip(title: isMedium ? "UP NEXT TODAY" : slot.period.title)
                    .textCase(.uppercase)
                Spacer(minLength: 4)
                slot.time.widgetTime
                    .font(.system(size: isMedium ? 24 : 22, weight: .bold))
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)
            DoseNames(doses: slot.doses, limit: 2, onHero: true, showsDosage: isMedium)
            Spacer(minLength: 6)

            HStack(alignment: .center) {
                if isMedium {
                    Text("\(dayProgress.taken) of \(dayProgress.total) doses logged")
                        .font(.caption)
                        .opacity(0.88)
                } else {
                    Text(verbatim: "\(slot.doses.filter { $0.status == .taken }.count)/\(slot.doses.count)")
                        .font(.caption.weight(.semibold))
                        .opacity(0.88)
                }
                Spacer(minLength: 4)
                if isMedium {
                    HeroPill(title: slot.doses.count > 1 ? "LOG ALL" : "LOG NOW")
                } else {
                    HeroCheckButton(label: slot.doses.count > 1 ? "Take All" : "Take Now")
                }
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: Missed

    private func missed(_ slot: WidgetSnapshot.Slot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
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
                      onHero: false, showsDosage: isMedium, isMissed: true)
            Spacer(minLength: 6)
            Text("Take Now")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.warningAccent, in: Capsule())
                .widgetAccentable()
        }
    }

    // MARK: Complete

    private var complete: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
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

    private var shown: [WidgetSnapshot.Dose] { Array(doses.prefix(limit)) }
    private var hidden: Int { doses.count - shown.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, dose in
                HStack(spacing: 7) {
                    DoseMark(status: dose.status, isMissed: isMissed, onHero: onHero, size: 15)
                    Text(dose.name)
                        .font(.widgetSerif(doses.count > 1 || showsDosage ? 16 : 19))
                        .strikethrough(dose.status == .taken)
                        .opacity(dose.status.isSettled ? 0.6 : 1)
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
                .foregroundStyle(onHero ? Color.white : Color.textPrimary)
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
                    Image(systemName: "exclamationmark.circle.fill")
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
                Text("Nothing for today").font(.headline)
                if let tomorrow {
                    HStack(spacing: 4) {
                        Text("Tomorrow")
                        tomorrow.time.widgetTime
                    }
                    .font(.caption)
                }
            case .needsApp:
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
