//
//  BackgroundExecution.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import UIKit

// MARK: - BackgroundExecution

/// Asks iOS for time to finish after the intent returns; ended once, or by iOS
/// when the time runs out.
@MainActor
final class BackgroundExecution {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
