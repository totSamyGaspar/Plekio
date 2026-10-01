//
//  PressableButtonStyle.swift
//  Plekio
//
//  Created by Edward Gasparian on 01.10.2026.
//

import SwiftUI

/// Shrinks a card-like button while pressed; nothing moves under Reduce Motion.
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .motion(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
