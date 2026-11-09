//
//  DoseNames.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

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
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 7) {
                Text(dose.name)
                    .font(.widgetSerif(doses.count > 1 || showsDosage ? 16 : 19))
                    .lineLimit(1)
                if showsDosage {
                    Text("\(dose.dosage) pcs")
                        .font(.caption2)
                        .opacity(0.8)
                        .fixedSize()
                    // Inline when two doses share the card: two extra lines would push out the bottom row.
                    if shown.count > 1, let mealTiming = dose.mealTimingTitle, dose.status == .pending {
                        Image(systemName: WidgetSnapshot.Dose.mealTimingImage)
                            .font(.caption2)
                            .opacity(0.8)
                            .accessibilityLabel(Text(mealTiming))
                    }
                }
                moreLabel(index: index)
            }
            if showsDosage, shown.count == 1, let mealTiming = dose.mealTimingTitle, dose.status == .pending {
                Label {
                    Text(mealTiming)
                } icon: {
                    Image(systemName: WidgetSnapshot.Dose.mealTimingImage)
                }
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .opacity(0.85)
                .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func moreLabel(index: Int) -> some View {
        if index == shown.count - 1, hidden > 0 {
            Text("\(hidden) more")
                .font(.caption2.weight(.semibold))
                .opacity(0.8)
                .fixedSize()
        }
    }
}
