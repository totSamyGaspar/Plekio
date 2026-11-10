//
//  WidgetColors.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

extension Color {

    // MARK: - Surface

    /// The widget's own background. Light: the app's screen cream, as pure white
    /// glares on a Home Screen. Dark: the card colour; the app's near-black screen
    /// colour would read as a hole in a dark Home Screen.
    /// Keep in sync with Assets.xcassets/WidgetBackground, which iOS draws while the
    /// widget loads and in edit mode.
    static let widgetSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
            : UIColor(red: 0.953, green: 0.945, blue: 0.914, alpha: 1)
    })

    // MARK: - Hero

    /// Ink of the white "LOG ALL" button on the hero card (UpNextHeroCard).
    static let onHeroButton = Color(red: 0.05, green: 0.3, blue: 0.2)

    static let heroHeart = Color(red: 1, green: 0.78, blue: 0.8)
}
