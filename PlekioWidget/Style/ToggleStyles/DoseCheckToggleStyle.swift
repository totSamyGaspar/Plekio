//
//  DoseCheckToggleStyle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// Every log control on the widgets is a Toggle(isOn:intent:), not a Button: WidgetKit
// draws the new state the moment it is tapped, while the intent runs in the app,
// and redraws from the snapshot once it's done. A Button would sit dimmed until then.
// The styles draw from `configuration.isOn`; the tap itself is WidgetKit's.

/// A dose's own check, as on Today's cards.
struct DoseCheckToggleStyle: ToggleStyle {
    var isMissed = false
    var onHero = false
    var size: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        DoseMark(
            status: configuration.isOn ? .taken : .pending,
            isMissed: isMissed && !configuration.isOn,
            onHero: onHero,
            size: size
        )
        .frame(width: size + 6, height: size + 6)
        .contentShape(Rectangle())
    }
}
