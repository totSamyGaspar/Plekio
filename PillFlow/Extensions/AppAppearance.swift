//
//  AppAppearance.swift
//  PillFlow
//

import SwiftUI
import UIKit

//  UIKit-level appearance, and the UIColor twins the frameworks that predate
//  SwiftUI still need.
//
//  Separate because it is the only part of the theme that reaches outside
//  SwiftUI, and the only part that has to be applied imperatively at launch
//  rather than declared on a view.

// MARK: - UIKit-level appearance

/// Appearance that SwiftUI has no modifier for.
enum AppAppearance {

    /// A slider's `.tint` colors its filled track only — the round thumb stays
    /// white in both themes and SwiftUI exposes no way to change it, so it goes
    /// through UIKit's appearance proxy. Applies to every slider in the app,
    /// including the before/after split handle.
    static func configureSliders() {
        UISlider.appearance().thumbTintColor = .appAccent
    }
}

// MARK: - UIKit twins

/// The tab bar is configured through `UITabBarAppearance`, which takes UIColor
/// and resolves it against its own trait collection. A `UIColor(Color)` bridge
/// would be flattened at configuration time — in `App.init`, before any window
/// exists — so these are built as dynamic UIColors from the start.
extension UIColor {

    static let appAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemMint.resolvedColor(with: .darkAppearance)
            : UIColor(red: 0.122, green: 0.478, blue: 0.396, alpha: 1)
    }

    /// The surface color with no transparency, for the tab bar when Reduce
    /// Transparency rules the blur out.
    static let appSurfaceOpaque = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    }

    /// Wash over the tab bar blur: darkens the bar in the dark theme, lifts it
    /// off the cream background in the light one.
    static let appTabBarWash = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.4)
            : UIColor.white.withAlphaComponent(0.55)
    }
}
