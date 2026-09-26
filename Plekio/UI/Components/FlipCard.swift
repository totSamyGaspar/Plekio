//
//  FlipCard.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

/// Two faces of one card that turns over around the vertical axis.
/// The front sets the size; the back is laid out in exactly the same frame.
struct FlipCard<Front: View, Back: View>: View {

    // MARK: - Properties

    let isFlipped: Bool
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back

    // MARK: - Body

    var body: some View {
        front
            .modifier(FlipFace(angle: isFlipped ? 180 : 0))
            .allowsHitTesting(!isFlipped)
            .accessibilityHidden(isFlipped)
            .overlay {
                back
                    .modifier(FlipFace(angle: isFlipped ? 0 : -180))
                    .allowsHitTesting(isFlipped)
                    .accessibilityHidden(!isFlipped)
            }
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
