//
//  UpNextView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - UpNextView

struct UpNextView: View {
    let entry: DoseEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(UpNext(entry).link.url)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        // The Lock Screen draws its own backdrop; WidgetKit still expects a container background.
        case .accessoryRectangular:
            UpNextRectangular(entry: entry).containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            UpNextInline(entry: entry).containerBackground(for: .widget) { Color.clear }
        default:
            let card = UpNextCard(entry: entry, isMedium: family == .systemMedium)
            card.containerBackground(for: .widget) { card.background }
        }
    }
}
