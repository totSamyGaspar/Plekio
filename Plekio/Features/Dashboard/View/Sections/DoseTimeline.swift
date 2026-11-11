//
//  DoseTimeline.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI
import TipKit

/// The day's doses by part of the day. `onAction` gets the section the dose is in:
/// opening a dose takes the open doses of its slot from it.
struct DoseTimeline: View {
    let morning: [PillDose]
    let noon: [PillDose]
    let evening: [PillDose]
    let onAction: (DoseCardAction, PillDose, [PillDose]) -> Void

    private let checkmarkTip = DoseCheckmarkTip()

    private var hasPills: Bool {
        !(morning.isEmpty && noon.isEmpty && evening.isEmpty)
    }

    var body: some View {
        LazyVStack(spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Dosage Timeline")
                        .scaledFont(size: 24, relativeTo: .title2, weight: .heavy, design: .serif)
                        .foregroundColor(.textPrimary)
                    Text("Your medications for today")
                        .font(.subheadline)
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if hasPills {
                TipView(checkmarkTip)
                    .padding(.horizontal)
            }

            section(morning, title: DayPeriod.morning.title)
            section(noon, title: DayPeriod.noon.title)
            section(evening, title: DayPeriod.evening.title)
        }
    }

    @ViewBuilder
    private func section(_ pills: [PillDose], title: LocalizedStringResource) -> some View {
        if !pills.isEmpty {
            PeriodSectionView(title: title, pills: pills) { action, pill in
                if action == .toggle { checkmarkTip.invalidate(reason: .actionPerformed) }
                onAction(action, pill, pills)
            }
        }
    }
}
