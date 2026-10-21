//
//  AccentColor.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import UIKit

// MARK: - UIColor+Accent

/// In Shared, not with the other UIKit twins in AppAppearance, because the widget
/// draws with the same accent. `nonisolated`: resolved wherever the colour is drawn.
nonisolated extension UIColor {

    /// Keep in sync with `Assets.xcassets/AccentColor` (used by UIKit controls).
    static let appAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemMint.resolvedColor(with: traits)
            : UIColor(red: 0.122, green: 0.478, blue: 0.396, alpha: 1)
    }
}
