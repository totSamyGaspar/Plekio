//
//  AppFeatures.swift
//  Plekio
//
//  Created by Edward Gasparian on 08.10.2026.
//

import Foundation

// MARK: - AppFeatures

/// Features that ship in the code but not to users yet. Each is read in one
/// place, the composition root, so switching one on is a one-line change.
nonisolated enum AppFeatures {

    /// Off for the first release: tips need the Paid Apps agreement and, in the
    /// EU, trader status under the DSA. The tip jar, its tests and Plekio.storekit
    /// stay ready; turning this on also needs the three products in App Store
    /// Connect and the Tips sections back in docs/privacy-policy.md and docs/terms.md.
    static let tips = false
}
