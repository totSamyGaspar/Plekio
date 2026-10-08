//
//  AppBrand.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.09.2026.
//

import Foundation

// MARK: - AppBrand

nonisolated enum AppBrand {

    static let name = "Plekio"

    /// Asset-catalogue image shared by the screens and the exported document.
    static let logoAssetName = "Logo"

    /// "1.0 (1)": the marketing version and build from the bundle, so it always
    /// matches the build that is running. Set in the target's General tab.
    static let version = "\(marketingVersion) (\(bundleValue("CFBundleVersion")))"

    /// "1.0": what the App Store shows; a new one is a new release.
    static let marketingVersion = bundleValue("CFBundleShortVersionString")

    /// Where feedback and support mail goes; also printed in the privacy policy.
    static let supportEmail = "plekio.support@gmail.com"

    /// GitHub Pages, published from docs/ on main: the Support URL in App Store Connect.
    static let supportURL = URL(string: "https://totsamygaspar.github.io/Plekio/")!

    /// The Privacy Policy URL in App Store Connect; App Review also expects it in the app.
    static let privacyPolicyURL = supportURL.appending(path: "privacy-policy.html")

    /// Medical disclaimer and limits of liability; the custom EULA if App Store Connect asks.
    static let termsURL = supportURL.appending(path: "terms.html")

    private static func bundleValue(_ key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? "?"
    }
}
