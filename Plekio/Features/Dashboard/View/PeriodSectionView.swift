//
//  PeriodSectionView.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI

struct PeriodSectionView: View {

    // MARK: - Properties

    let title: LocalizedStringResource
    let pills: [PillDose]
    let onAction: (DoseCardAction, PillDose) -> Void

    private var timeString: String {
        guard let first = pills.first?.time else { return "" }
        let firstText = first.formatted(date: .omitted, time: .shortened)

        guard let last = pills.last?.time, last != first else { return firstText }
        return "\(firstText) – \(last.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(Color.accentPrimary).frame(width: 10, height: 10)
                    .shadow(color: .accentPrimary.opacity(0.5), radius: 4)
                Text(title).font(.headline).foregroundColor(.textPrimary)
                Spacer()
                Text(timeString).font(.subheadline).foregroundColor(.textSecondary)
            }

            ForEach(pills) { pill in
                MedicationCardView(pill: pill) { action in
                    withMotion(Motion.bouncy) {
                        onAction(action, pill)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
