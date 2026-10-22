//
//  HeroPill.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// The white pill button of the hero card; stage 4 wraps it in an intent button.
struct HeroPill: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Color.onHeroButton)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Color.white, in: Capsule())
            .widgetAccentable()
    }
}
