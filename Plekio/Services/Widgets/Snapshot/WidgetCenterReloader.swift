//
//  WidgetCenterReloader.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import WidgetKit

// MARK: - WidgetCenterReloader

struct WidgetCenterReloader: WidgetReloading {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
