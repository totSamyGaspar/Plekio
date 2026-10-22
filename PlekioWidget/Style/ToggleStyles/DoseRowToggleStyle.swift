//
//  DoseRowToggleStyle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// MARK: - DoseRowToggleStyle

/// A whole medication line on the up-next card: the mark, then the label, struck
/// through once taken.
struct DoseRowToggleStyle: ToggleStyle {
    var isMissed = false
    var onHero = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            DoseMark(
                status: configuration.isOn ? .taken : .pending,
                isMissed: isMissed && !configuration.isOn,
                onHero: onHero,
                size: 15
            )
            configuration.label
                .strikethrough(configuration.isOn)
                .opacity(configuration.isOn ? 0.6 : 1)
        }
        .contentShape(Rectangle())
    }
}
