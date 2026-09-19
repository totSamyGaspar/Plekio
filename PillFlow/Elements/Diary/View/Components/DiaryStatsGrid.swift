//
//  DiaryStatsGrid.swift
//  PillFlow
//

import SwiftUI

/// The four seven-day averages above the sub-tabs.
///
/// Takes the numbers, not the view model: nothing here needs to know where they
/// came from, and a grid of four figures is the easiest thing in the screen to
/// get wrong unnoticed.
struct DiaryStatsGrid: View {
    
    let avgMoodScore: Double
    let avgEnergyLevel: Double
    let totalPhotosLogged: Int
    let avgSleepHours: Double
    
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
