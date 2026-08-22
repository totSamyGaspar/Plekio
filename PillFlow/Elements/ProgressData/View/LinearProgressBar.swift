//
//  LinearProgressBar.swift
//  PillFlow
//
//  Created by Edward Gasparian on 19.05.2026.
//

import SwiftUI

struct LinearProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 8)

                // Filled portion
                Capsule()
                    .fill(Color.neonMint)
                    .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                // Subtle glow for a cyberpunk vibe
                    .shadow(color: Color.neonMint.opacity(0.4), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 8)
    }
}
