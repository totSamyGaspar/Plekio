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
    /// Shared by the week's cells so the highlight slides between them.
    let selection: Namespace.ID

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
        .background(
            isSelected ? Color.clear : Color.textPrimary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .selectionAnchor(date, in: selection)
        // Tapped via onTapGesture, so the button trait is added manually.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var selection
    let today = Calendar.current.startOfDay(for: Date())
    let tomorrow = today.addingTimeInterval(86_400)
    HStack {
        CalendarDayView(date: today, isSelected: true, selection: selection)
        CalendarDayView(date: tomorrow, isSelected: false, selection: selection)
    }
    .selectionIndicator(following: today, in: selection, shape: RoundedRectangle(cornerRadius: 16), fill: .accentPrimary)
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
