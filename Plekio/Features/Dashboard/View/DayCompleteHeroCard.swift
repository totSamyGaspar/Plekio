//
//  DayCompleteHeroCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// The back of the Today hero card, shown once every dose of today is taken or skipped.
/// Mirrors the front's rhythm: headline, count, divider, bottom row.
struct DayCompleteHeroCard: View {

    // MARK: - Properties

    let date: Date
    let takenCount: Int
    let totalCount: Int
    let streakDays: Int
    /// Starts the seal's bounce when the card turns to this side.
    let isShown: Bool

    private var progress: Double {
        totalCount > 0 ? Double(takenCount) / Double(totalCount) : 0
    }

    // MARK: - Body

    var body: some View {
        HeroCard(title: "ALL DONE TODAY", systemImage: "checkmark", date: date, fillsHeight: true) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .scaledFont(size: 24, relativeTo: .title, weight: .bold)
                    .symbolEffect(.bounce, value: isShown)
                Text("Day complete")
                    .scaledFont(size: 28, relativeTo: .largeTitle, weight: .heavy, design: .serif)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(.white)

            Text("\(takenCount) of \(totalCount) doses logged")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

            Spacer(minLength: 0)

            Divider().background(Color.white.opacity(0.3))

            HStack(spacing: 14) {
                CircularProgressView(progress: progress, palette: .onHero, size: .compact)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(verbatim: "🔥")
                        Text("\(streakDays) days streak!")
                            .animatedNumber(Double(streakDays))
                    }
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    Text("Keep it up tomorrow")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    DayCompleteHeroCard(date: Date(), takenCount: 4, totalCount: 4, streakDays: 5, isShown: true)
        .frame(height: 280)
        .appTheme()
}
#endif
