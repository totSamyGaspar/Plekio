//
//  UpNextCard.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

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
                // Always one line at full size: it's what the card is for. The chip gives way.
                slot.time.widgetTime
                    .font(.system(size: isMedium ? 24 : 20, weight: .bold))
                    .lineLimit(1)
                    .fixedSize()
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
        .heroTextShadow()
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
                    .accessibilityHidden(true)
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
        .heroTextShadow()
    }

    @ViewBuilder
    private var streak: some View {
        if let days = snapshot?.streakDays, days > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .accessibilityHidden(true)
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
