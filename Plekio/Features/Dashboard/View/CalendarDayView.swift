//
//  CalendarDayView.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//

import SwiftUI

struct CalendarDayView: View {

    // MARK: - Properties

    let date: Date
    let isSelected: Bool

    /// Fixed (but scaled) width so one- and two-digit days line up.
    @ScaledMetric(relativeTo: .title3) private var cellWidth: CGFloat = 56

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.bold))
                .foregroundColor(isSelected ? .onAccent : .textSecondary)
            // Fixed width: long localized abbreviations may shrink slightly.
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(date.formatted(.dateTime.day()))
                .font(.title3.weight(.bold))
                .foregroundColor(isSelected ? .onAccent : .textPrimary)
        }
        .padding(.vertical, 12)
        .frame(width: cellWidth)
        .background(isSelected ? Color.accentPrimary : Color.textPrimary.opacity(0.05))
        .cornerRadius(16)
        // Tapped via onTapGesture, so the button trait is added manually.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview {
    HStack {
        CalendarDayView(date: Date(), isSelected: true)
        CalendarDayView(date: Date(), isSelected: false)
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
