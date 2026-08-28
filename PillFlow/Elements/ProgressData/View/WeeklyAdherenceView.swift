//
//  WeeklyAdherenceView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 11.06.2026.
//

import SwiftUI

struct WeeklyAdherenceView: View {
    let percentages: [Double]
    let days: [String]
    let recentAverage: Int

    /// Ratio/label pairs. The view used to run ForEach(0..<7) and index into
    /// both arrays: a length mismatch — and `weeklyDays` starts empty — crashed
    /// during rendering.
    private var bars: [(offset: Int, element: (Double, String))] {
        Array(zip(percentages, days).enumerated())
    }

    let cardDark = Color.cardDark

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEKLY ADHERENCE HISTORY")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.neonMint)
                    .tracking(1.0)
                
                Text("Compliance rates over past 7 cycles")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            HStack(spacing: 12) {
                ForEach(bars, id: \.offset) { _, bar in
                    let (percent, label) = bar
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                TopRoundedBar()
                                    .fill(Color.white.opacity(0.05))
                                TopRoundedBar()
                                    .fill(Color.neonMint)
                                    .frame(height: geo.size.height * min(max(percent, 0), 1))
                                    .shadow(color: Color.neonMint.opacity(0.3), radius: 5, x: 0, y: -5)
                            }
                        }
                        .frame(height: 80)

                        Text(label)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            HStack(alignment: .bottom) {
                // One value formatted as .percent instead of a number plus a separate
                // "%": the order and the spacing before the sign differ by locale and
                // cannot be expressed by concatenation.
                Text(Double(recentAverage) / 100, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .italic()
                
                Text("recent average")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 6)
                    .padding(.leading, 4)
                Spacer()
                
                Text("Optimal")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.neonMint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.neonMint.opacity(0.15))
                    .cornerRadius(10)
                    .padding(.bottom, 6)
            }
        }
        .padding(20)
        .background(cardDark)
        .cornerRadius(24)
        .padding(.horizontal)
    }
}
