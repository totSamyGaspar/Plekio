//
//  WeeklyAdherenceView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 11.06.2026.
//

import SwiftUI

struct WeeklyAdherenceView: View {
    // Temporary mock data for the visuals (wire up to real stats later)
    let percentages: [Double]
    let days: [String]
    let recentAverage: Int

    // Reuse the shared color from Theme instead of a hardcoded RGB value
    let cardDark = Color.cardDark

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEKLY ADHERENCE HISTORY")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.mint)
                    .tracking(1.0)
                
                Text("Compliance rates over past 7 cycles")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Capsule chart
            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .bottom) {
                                TopRoundedBar()
                                    .fill(Color.white.opacity(0.05))
                                TopRoundedBar()
                                    .fill(Color.mint)
                                    .frame(height: geo.size.height * percentages[index])
                                    .shadow(color: Color.mint.opacity(0.3), radius: 5, x: 0, y: -5)
                            }
                        }
                        .frame(height: 80)

                        Text(days[index])
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Summary
            HStack(alignment: .bottom) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(recentAverage)")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .italic()
                    Text("%")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .italic()
                }
                
                Text("recent average")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 6)
                    .padding(.leading, 4)
                Spacer()
                
                Text("Optimal")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.mint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.mint.opacity(0.15))
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
