//
//  HeroBackground.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// The Today hero card's time-of-day gradient, by the entry's hour, not the clock's.
struct HeroBackground: View {
    let date: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var colors: [Color] {
        switch Calendar.autoupdatingCurrent.component(.hour, from: date) {
        case 5..<12: [.heroMorningStart, .heroMorningEnd]
        case 12..<18: [.heroNoonStart, .heroNoonEnd]
        default: [.heroEveningStart, .heroEveningEnd]
        }
    }

    var body: some View {
        // Tinted and clear Home Screens draw their own background; a gradient would only muddy it.
        if renderingMode == .fullColor {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.clear
        }
    }
}
