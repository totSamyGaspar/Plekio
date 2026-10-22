//
//  MissedTakeToggleStyle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// The missed card's red "Take now"; a check once tapped.
struct MissedTakeToggleStyle: ToggleStyle {
    let title: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if configuration.isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
            } else {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.warningAccent, in: Capsule())
        .widgetAccentable()
    }
}
