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
    var palette: Palette = .standard
    var size: Size = .regular

    // MARK: - Size

    enum Size {
        case regular
        /// For a small ring inside a row.
        case compact

        var track: CGFloat { self == .regular ? 16 : 7 }
        var ring: CGFloat { self == .regular ? 12 : 6 }
        var inset: CGFloat { self == .regular ? 20 : 4 }
        var fontSize: CGFloat { self == .regular ? 15 : 12 }
    }

    // MARK: - Palette

    struct Palette {
        let track: Color
        let ring: [Color]
        let text: Color

        static let standard = Palette(
            track: .accentPrimary.opacity(0.2),
            ring: [.accentPrimary, .accentSecondary],
            text: .textPrimary
        )

        /// On the hero card's gradient.
        static let onHero = Palette(track: .white.opacity(0.25), ring: [.white, .white.opacity(0.85)], text: .white)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.track, lineWidth: size.track)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    LinearGradient(colors: palette.ring, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: size.ring, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .motion(Motion.progress, value: progress)

            // .percent format so the sign's placement follows the locale.
            VStack(spacing: 2) {
                Text(min(max(progress, 0), 1), format: .percent.precision(.fractionLength(0)))
                    .scaledFont(size: size.fontSize, relativeTo: .subheadline, weight: .semibold, design: .serif)
                    .foregroundColor(palette.text)
                    .animatedNumber(progress)
            }
        }
        .completionPulse(progress >= 1)
        .padding(size.inset)
    }
}
