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
    static let version: String = {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(marketing) (\(build))"
    }()
}
