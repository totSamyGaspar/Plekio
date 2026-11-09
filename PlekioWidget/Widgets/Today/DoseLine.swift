//
//  DoseLine.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

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

            HStack(spacing: 4) {
                Text(dose.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(dose.status.isSettled ? Color.textSecondary : Color.textPrimary)
                    .strikethrough(dose.status == .taken)
                    .lineLimit(1)

                // Only the icon fits; VoiceOver reads the words.
                if let mealTiming = dose.mealTimingTitle {
                    Image(systemName: WidgetSnapshot.Dose.mealTimingImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .accessibilityLabel(Text(mealTiming))
                }
            }
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
