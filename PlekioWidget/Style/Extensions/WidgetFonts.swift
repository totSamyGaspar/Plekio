//
//  WidgetFonts.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

extension Font {

    /// The app's serif headings (medication names, "Day complete").
    static func widgetSerif(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
