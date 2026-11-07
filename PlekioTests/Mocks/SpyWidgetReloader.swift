//
//  SpyWidgetReloader.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation
@testable import Plekio

/// Counts reloads instead of asking WidgetCenter.
@MainActor
final class SpyWidgetReloader: WidgetReloading {
    private(set) var reloadCount = 0

    func reloadAll() {
        reloadCount += 1
    }
}
