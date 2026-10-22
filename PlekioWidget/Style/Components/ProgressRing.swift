//
//  ProgressRing.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// MARK: - Progress

/// The app's progress ring (CircularProgressView), without animation: a widget is a still.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var track: Color = .accentPrimary.opacity(0.2)
    var ring: [Color] = [.accentPrimary, .accentSecondary]

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(colors: ring, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth - 1, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .padding(lineWidth / 2)
    }
}
