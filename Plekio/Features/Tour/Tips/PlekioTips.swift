//
//  PlekioTips.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import TipKit

/// One-time hints shown where a feature lives, the first time the user gets there.
/// Held back until the first-run tour is over, so the two never compete.
enum PlekioTips {
    @Parameter static var tourFinished: Bool = false

    static func configure() {
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}
