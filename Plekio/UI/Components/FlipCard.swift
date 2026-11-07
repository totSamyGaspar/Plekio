//
//  FlipCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// Two faces of one card that turns over around the vertical axis.
/// The card takes the height of the face that is showing, so a short back doesn't
/// sit in a tall front's frame; the height changes with the turn.
struct FlipCard<Front: View, Back: View>: View {

    // MARK: - Properties

    let isFlipped: Bool
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back

    /// Each face's own height, measured at its ideal size. Nil until laid out,
    /// when the card simply fits both.
    @State private var frontHeight: CGFloat?
    @State private var backHeight: CGFloat?

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            front
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { frontHeight = $0 }
                .modifier(FlipFace(angle: isFlipped ? 180 : 0))
                .allowsHitTesting(!isFlipped)
                .accessibilityHidden(isFlipped)

            back
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { backHeight = $0 }
                .modifier(FlipFace(angle: isFlipped ? 0 : -180))
                .allowsHitTesting(isFlipped)
                .accessibilityHidden(!isFlipped)
        }
        .frame(height: isFlipped ? backHeight : frontHeight, alignment: .top)
        .motion(Motion.flip, value: isFlipped)
    }
}

// MARK: - FlipFace

/// Rotates one face and hides it once it turns past edge-on, frame by frame,
/// so the two faces never show at the same time.
private struct FlipFace: ViewModifier, Animatable {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(abs(angle) < 90 ? 1 : 0)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}
