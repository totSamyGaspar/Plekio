//
//  CircularProgressView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 06.05.2026.
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double // 0.0 to 1.0
    let goal: Int // goal in percent, e.g. 90

    // Gradient for the filled portion
    let ringGradient = LinearGradient(
        colors: [Color.mint, Color.teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Background ring (translucent mint so it stands out against the blue)
            Circle()
                .stroke(Color.mint.opacity(0.2), lineWidth: 16)

            // Filled ring
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

            // Text inside the ring
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                
                Text("GOAL \(goal)%")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(20)
    }
}
