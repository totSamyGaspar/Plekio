//
//  DaySummaryLine.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI

/// Shown instead of the hero card; describes the selected day, not today.
struct DaySummaryLine: View {
    let date: Date
    let takenCount: Int
    let totalCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.title3.weight(.bold))
                .foregroundColor(.textPrimary)

            Text("\(takenCount) of \(totalCount) doses logged")
                .font(.subheadline)
                .foregroundColor(.accentPrimary)
                .animatedNumber(Double(takenCount))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}
