//
//  AppAppearance.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import SwiftUI
import UIKit

// MARK: - AppAppearance

/// UIKit appearance that SwiftUI has no modifier for; applied at launch.
enum AppAppearance {

    /// SwiftUI `.tint` doesn't colour the slider thumb; set it app-wide via UIKit.
    static func configureSliders() {
        UISlider.appearance().thumbTintColor = .appAccent
    }
}

// MARK: - UIKit twins

/// Dynamic UIColors for UIKit appearance; a `UIColor(Color)` bridge would be
/// resolved once in `App.init` and stop following the theme. `nonisolated`:
/// the providers run wherever the colour is resolved, not only on the main actor.
nonisolated extension UIColor {

    static let appAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemMint.resolvedColor(with: traits)
            : UIColor(red: 0.122, green: 0.478, blue: 0.396, alpha: 1)
    }

    /// Opaque surface for the tab bar under Reduce Transparency.
    static let appSurfaceOpaque = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    }

    /// Tint over the tab bar blur.
    static let appTabBarWash = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.4)
            : UIColor.white.withAlphaComponent(0.55)
    }
}
