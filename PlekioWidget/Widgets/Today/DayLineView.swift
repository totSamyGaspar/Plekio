//
//  DayLineView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

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
