//
//  HeroChip.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// The dark capsule label at the top of a hero card ("UP NEXT TODAY").
struct HeroChip: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            // Shrinks before it wraps: whatever sits beside it keeps its line.
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 10, weight: .heavy))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.15), in: Capsule())
    }
}
