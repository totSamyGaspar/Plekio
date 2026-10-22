//
//  DoseMark.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// A dose's state as a symbol, the same ones Today uses.
struct DoseMark: View {
    let status: WidgetSnapshot.Status
    var isMissed = false
    /// On a hero gradient everything is white; on a card it takes the app's tints.
    var onHero = false
    var size: CGFloat = 18

    private var symbol: String {
        switch status {
        case .taken: "checkmark.circle.fill"
        case .skipped: "minus.circle"
        case .pending: onHero ? "circle.dotted.circle" : "checkmark.circle"
        }
    }

    private var tint: Color {
        if onHero { return status == .pending ? .white : .white.opacity(0.6) }
        switch status {
        case .taken: return .accentPrimary
        case .skipped: return .textSecondary
        case .pending: return isMissed ? .warningAccent : .textTertiary
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(tint)
            .widgetAccentable(status == .taken)
            .accessibilityHidden(true)
    }
}
