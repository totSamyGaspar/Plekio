//
//  WeeklyAdherenceView.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.06.2026.
//

import SwiftUI

struct WeeklyAdherenceView: View {

    // MARK: - Properties

    let percentages: [Double]
    let days: [String]
    let recentAverage: Int

    /// Zipped so a length mismatch cannot crash rendering (`weeklyDays` starts empty).
    private var bars: [(offset: Int, element: (Double, String))] {
        Array(zip(percentages, days).enumerated())
    }

    let appSurface = Color.appSurface

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEKLY ADHERENCE HISTORY")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.accentPrimary)
                    .tracking(1.0)

                Text("Compliance rates over past 7 cycles")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary.opacity(0.7))
            }

            HStack(spacing: 12) {
                ForEach(bars, id: \.offset) { _, bar in
                    let (percent, label) = bar
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                TopRoundedBar()
                                    .fill(Color.textPrimary.opacity(0.05))
                                TopRoundedBar()
                                    .fill(Color.accentPrimary)
                                    .frame(height: geo.size.height * min(max(percent, 0), 1))
                                    .shadow(color: Color.accentPrimary.opacity(0.3), radius: 5, x: 0, y: -5)
                            }
                        }
                        .frame(height: 80)

                        Text(label)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.textSecondary)
                    }
                    // Shapes are invisible to VoiceOver, so the value is added explicitly.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
                    .accessibilityValue(Text(percent, format: .percent.precision(.fractionLength(0))))
                }
            }

            Divider().background(Color.textPrimary.opacity(0.2))

            HStack(alignment: .bottom) {
                // Formatted as .percent: sign position and spacing vary by locale.
                Text(Double(recentAverage) / 100, format: .percent.precision(.fractionLength(0)))
                    .scaledFont(size: 40, relativeTo: .largeTitle, weight: .bold, design: .serif)
                    .foregroundColor(.textPrimary)
                    .italic()

                Text("recent average")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .padding(.bottom, 6)
                    .padding(.leading, 4)
                Spacer()

                Text("Optimal")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentPrimary.opacity(0.15))
                    .cornerRadius(10)
                    .padding(.bottom, 6)
            }
        }
        .padding(20)
        .background(appSurface)
        .cornerRadius(24)
        .padding(.horizontal)
    }
}
