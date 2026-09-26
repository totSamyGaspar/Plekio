//
//  AdherenceSummaryView.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// Today's adherence ring next to the streak.
struct AdherenceSummaryView: View {

    // MARK: - Properties

    let progress: Double
    let streakDays: Int

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            CircularProgressView(progress: progress)
                .frame(height: 100)

            VStack(spacing: 10) {
                Text(verbatim: "🔥")
                    .font(.headline.weight(.bold))
                Text("\(streakDays) days streak!")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .animatedNumber(Double(streakDays))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.textPrimary.opacity(0.15))
            .cornerRadius(20)
        }
    }
}
