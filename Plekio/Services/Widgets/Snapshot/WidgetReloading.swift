//
//  WidgetReloading.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import WidgetKit

// MARK: - WidgetReloading

/// Asks the system to redraw the widgets. A protocol so tests can count reloads:
/// in the background they come out of a daily budget, so none may be wasted.
protocol WidgetReloading {
    func reloadAll()
}
