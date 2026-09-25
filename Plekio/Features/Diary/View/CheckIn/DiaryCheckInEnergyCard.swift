//
//  DiaryCheckInEnergyCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import SwiftUI

/// Energy and discomfort, the two sliders that share a card.
struct DiaryEnergyDiscomfortCard: View {

    // MARK: - Properties

    @Binding var energyLevel: Int
    @Binding var discomfortLevel: Int
    /// Wording comes from DiaryEntryDraft.energyDescription.
    let energyDescription: LocalizedStringResource
    let discomfortDescription: LocalizedStringResource

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            DiarySliderRow(
                icon: "bolt.fill",
                iconColor: .yellow,
                title: "Energy Level: \(energyLevel)/5",
                trailingLabel: energyDescription,
                value: Binding(
                    get: { Double(energyLevel) },
                    set: { energyLevel = Int($0.rounded()) }
                ),
                range: 1...5,
                tint: .accentPrimary,
                minLabel: "Low", midLabel: "Moderate", maxLabel: "Peak"
            )

            Divider().opacity(0.15)

            DiarySliderRow(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Discomfort/Pain: \(discomfortLevel)/10",
                trailingLabel: discomfortDescription,
                value: Binding(
                    get: { Double(discomfortLevel) },
                    set: { discomfortLevel = Int($0.rounded()) }
                ),
                range: 0...10,
                tint: .pink,
                minLabel: "0 (None)", midLabel: "5 (Manageable)", maxLabel: "10 (Severe)"
            )
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
    }
}
