//
//  DiaryStatsGrid.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI

/// The four summary stats above the diary sub-tabs.
struct DiaryStatsGrid: View {

    // MARK: - Properties

    let avgMoodScore: Double
    let avgEnergyLevel: Double
    let totalPhotosLogged: Int
    let avgSleepHours: Double

    // MARK: - Body

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            card(
                title: "7-DAY AVG MOOD",
                value: "\(avgMoodScore, format: .number.precision(.fractionLength(1))) /5",
                icon: "sun.max.fill",
                iconColor: .yellow
            )
            card(
                title: "7-DAY AVG ENERGY",
                value: "\(avgEnergyLevel, format: .number.precision(.fractionLength(1))) /5",
                icon: "bolt.fill",
                iconColor: .accentPrimary
            )
            card(
                title: "PROGRESS PHOTOS · ALL TIME",
                value: "\(totalPhotosLogged) logged",
                icon: "camera.fill",
                iconColor: .textPrimary.opacity(0.6)
            )
            card(
                title: "7-DAY SLEEP AVERAGE",
                value: "\(avgSleepHours, format: .number.precision(.fractionLength(1))) hrs",
                icon: "moon.fill",
                iconColor: .purple
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Subviews

    private func card(
        title: LocalizedStringKey,
        value: LocalizedStringKey,
        icon: String,
        iconColor: Color
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.textSecondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            Image(systemName: icon)
                .foregroundColor(iconColor)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appSurface)
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        DiaryStatsGrid(
            avgMoodScore: 4.2,
            avgEnergyLevel: 3.5,
            totalPhotosLogged: 12,
            avgSleepHours: 7.4
        )
    }
    .appTheme()
}
