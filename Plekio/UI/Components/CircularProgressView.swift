//
//  CircularProgressView.swift
//  Plekio
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI

struct CircularProgressView: View {

    // MARK: - Properties

    let progress: Double

    let ringGradient = LinearGradient(
        colors: [Color.accentPrimary, Color.accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Body

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentPrimary.opacity(0.2), lineWidth: 16)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motion(Motion.progress, value: progress)

            // .percent format so the sign's placement follows the locale.
            VStack(spacing: 2) {
                Text(min(max(progress, 0), 1), format: .percent.precision(.fractionLength(0)))
                    .scaledFont(size: 15, relativeTo: .subheadline, weight: .semibold, design: .serif)
                    .foregroundColor(.textPrimary)
                    .animatedNumber(progress)
            }
        }
        .completionPulse(progress >= 1)
        .padding(20)
    }
}
