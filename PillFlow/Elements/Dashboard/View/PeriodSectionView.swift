//
//  PeriodSectionView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI

struct PeriodSectionView: View {
    let title: String
    let timeString: String
    let pills: [PillDose]
    let isToday: Bool
    let onTogglePill: (UUID) -> Void
    let onPillTap: (PillDose) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle().fill(Color.neonMint).frame(width: 10, height: 10)
                    .shadow(color: .neonMint.opacity(0.5), radius: 4)
                Text(title).font(.headline).foregroundColor(.white)
                Spacer()
                Text(timeString).font(.subheadline).foregroundColor(.white.opacity(0.5))
            }

            ForEach(pills) { pill in
                MedicationCardView(
                    pill: pill,
                    isToday: isToday,
                    onToggle: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            onTogglePill(pill.id)
                            hapticFeedback()
                        }
                    },
                    onTapCard: {
                        onPillTap(pill)
                    }
                )
            }
        }
        .padding(.horizontal)
    }
    
    private func hapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}
