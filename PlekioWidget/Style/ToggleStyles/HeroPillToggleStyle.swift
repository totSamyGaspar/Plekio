//
//  HeroPillToggleStyle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// The hero card's white "LOG ALL" pill; a check once tapped.
struct HeroPillToggleStyle: ToggleStyle {
    let title: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        if configuration.isOn {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.onHeroButton)
                .frame(minWidth: 44)
                .padding(.vertical, 8)
                .background(Color.white, in: Capsule())
                .widgetAccentable()
        } else {
            HeroPill(title: title)
        }
    }
}
