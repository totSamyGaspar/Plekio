//
//  EmptyDayView.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// MARK: - EmptyDayView

/// Nothing scheduled today; tomorrow's first slot when there is one.
struct EmptyDayView: View {
    let tomorrow: WidgetSnapshot.Slot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetLogo()
            Spacer(minLength: 0)
            Text("Nothing for today")
                .font(.widgetSerif(17))
                .foregroundStyle(Color.textPrimary)
            if let tomorrow {
                HStack(spacing: 4) {
                    Text("Tomorrow")
                    Text(verbatim: "·")
                    tomorrow.time.widgetTime
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
