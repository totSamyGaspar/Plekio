//
//  MoodToggleStyle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 22.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

/// A mood tile as on the diary's Today card; picked at once when tapped.
struct MoodToggleStyle: ToggleStyle {
    let emoji: String
    let label: LocalizedStringKey
    var showsLabel = true

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: emoji)
                .font(.system(size: showsLabel ? 22 : 20))
            if showsLabel {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.textPrimary.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, showsLabel ? 8 : 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(configuration.isOn ? Color.accentPrimary.opacity(0.22) : Color.textPrimary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentPrimary, lineWidth: configuration.isOn ? 2 : 0)
        )
        .accessibilityLabel(Text(label))
    }
}
