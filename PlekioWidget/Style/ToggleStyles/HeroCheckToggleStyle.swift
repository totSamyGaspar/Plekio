//
//  HeroCheckToggleStyle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// The small widget's round check; filled once tapped.
struct HeroCheckToggleStyle: ToggleStyle {
    let label: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(configuration.isOn ? Color.white : Color.onHeroButton)
            .frame(width: 36, height: 36)
            .background(configuration.isOn ? Color.onHeroButton : Color.white, in: Circle())
            .widgetAccentable()
            .accessibilityLabel(Text(label))
    }
}
