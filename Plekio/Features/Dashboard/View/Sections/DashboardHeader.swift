//
//  DashboardHeader.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI

/// The wordmark at the top of Today.
struct DashboardHeader: View {

    /// Scales with the wordmark's text style under Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var logoSize: CGFloat = 34

    var body: some View {
        HStack(spacing: 10) {
            AppLogo(size: logoSize)

            Text(AppBrand.name)
                .scaledFont(size: 36, relativeTo: .largeTitle, weight: .heavy, design: .serif)
                .italic()
                .foregroundColor(.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}
