//
//  CircularProgressView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double

    let ringGradient = LinearGradient(
        colors: [Color.accentPrimary, Color.accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentPrimary.opacity(0.2), lineWidth: 16)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

            // .percent, not a number with a "%" glued on: the placement and spacing of
            // the sign follow the locale, which manual concatenation breaks.
            VStack(spacing: 2) {
                Text(min(max(progress, 0), 1), format: .percent.precision(.fractionLength(0)))
                    .scaledFont(size: 15, relativeTo: .subheadline, weight: .semibold, design: .serif)
                    .foregroundColor(.textPrimary)
            }
        }
        .padding(20)
    }
}
