//
//  HeroTextShadow.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI
import WidgetKit

/// A soft shadow under the white content of the hero card, so it stays readable on
/// the bright dark-theme gradients (mint, yellow). Lighter in the light theme, whose
/// gradients are already deep, and off on tinted and clear Home Screens.
struct HeroTextShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    func body(content: Content) -> some View {
        if renderingMode == .fullColor {
            content.shadow(
                color: .black.opacity(colorScheme == .dark ? 0.35 : 0.15),
                radius: colorScheme == .dark ? 2 : 1.5,
                x: 0,
                y: 1
            )
        } else {
            content
        }
    }
}

extension View {
    func heroTextShadow() -> some View {
        modifier(HeroTextShadow())
    }
}
