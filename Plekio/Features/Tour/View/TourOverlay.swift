//
//  TourOverlay.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// Dims the screen except the step's target and shows the step's card beside it.
/// Touches inside the cutout reach the view below, so a step can wait for a real tap.
struct TourOverlay: View {

    // MARK: - Properties

    let tour: TourCoordinator

    private static let cutoutPadding: CGFloat = 8
    private static let cornerRadius: CGFloat = 18

    // MARK: - Body

    var body: some View {
        ZStack {
            if let step = tour.step {
                GeometryReader { proxy in
                    let hole = tour.highlightedFrame?.insetBy(dx: -Self.cutoutPadding, dy: -Self.cutoutPadding)
                    let shape = SpotlightShape(hole: hole ?? .zero, cornerRadius: Self.cornerRadius)

                    ZStack(alignment: .topLeading) {
                        shape
                            .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                            // Only the dimmed part catches touches; the cutout passes them through.
                            .contentShape(shape, eoFill: true)
                            .onTapGesture {}

                        if let hole {
                            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                .frame(width: hole.width, height: hole.height)
                                .position(x: hole.midX, y: hole.midY)
                                .allowsHitTesting(false)
                        }

                        card(for: step, hole: hole, in: proxy.size)
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tour.step)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tour.highlightedFrame)
    }

    // MARK: - Card

    /// Below the target when it's in the top half, above it otherwise; centred without one.
    @ViewBuilder
    private func card(for step: TourStep, hole: CGRect?, in size: CGSize) -> some View {
        let card = TourCard(step: step, onNext: tour.next, onSkip: tour.skip)
            .padding(.horizontal, 20)
            .frame(width: size.width)

        if let hole {
            if hole.midY < size.height / 2 {
                VStack(spacing: 0) {
                    Color.clear.frame(height: hole.maxY + 12)
                    card
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    card
                    Color.clear.frame(height: max(size.height - hole.minY + 12, 0))
                }
            }
        } else {
            card.frame(maxHeight: .infinity)
        }
    }
}
