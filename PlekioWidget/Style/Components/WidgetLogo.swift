//
//  WidgetLogo.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// On every widget, so it reads as Plekio's at a glance. White on the hero gradient.
struct WidgetLogo: View {
    var size: CGFloat = 16
    var tint: Color = .accentPrimary

    var body: some View {
        Image("Logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}
