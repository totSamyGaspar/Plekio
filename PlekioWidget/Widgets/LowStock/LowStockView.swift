//
//  LowStockView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

/// The lowest medication, as on Today's refill card; stock doesn't depend on the day.
struct LowStockView: View {
    let entry: DoseEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if let low = snapshot.lowStock.first {
                    alert(low, others: snapshot.lowStock.count - 1)
                } else {
                    stocked
                }
            } else {
                NeedsAppView()
            }
        }
        .containerBackground(Color.widgetSurface, for: .widget)
        // Today shows the refill card, as the low-stock reminder's tap does.
        .widgetURL(WidgetLink.today.url)
    }

    private func alert(_ low: WidgetSnapshot.StockAlert, others: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header
                Spacer(minLength: 4)
                Text("LOW")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.warningAmber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.warningAmber, lineWidth: 1))
            }

            Spacer(minLength: 6)
            Text(low.name)
                .font(.widgetSerif(18))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
            Text("Stock: \(low.stock)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.warningAmber)
                .padding(.top, 2)
            Spacer(minLength: 6)

            // Against the threshold, so "low" reads the same as in the app.
            ProgressView(value: Double(min(low.stock, low.threshold)), total: Double(max(low.threshold, 1)))
                .tint(Color.warningAmber)
                // "Stock: 4" above already says it; a percentage of the threshold means nothing aloud.
                .accessibilityHidden(true)
            if others > 0 {
                Text("\(others) more")
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    /// Says what the widget is about: without it the "all stocked" state reads as a stray message.
    private var header: some View {
        HStack(spacing: 5) {
            WidgetLogo(size: 14)
            Text("Stock")
                .foregroundStyle(Color.textSecondary)
        }
        .font(.caption.weight(.bold))
        .lineLimit(1)
    }

    private var stocked: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 6)
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Color.accentPrimary)
                .widgetAccentable()
                .accessibilityHidden(true)
                .padding(.bottom, 6)
            // Long in some languages ("Tous les médicaments sont bien approvisionnés"): shrink, don't cut.
            Text("All medications are well stocked")
                .font(.widgetSerif(15, weight: .bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
