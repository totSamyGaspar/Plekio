//
//  CalendarDayView.swift
//  Plekio
//
//  Created by Edward Gasparian on 20.05.2026.
//


import SwiftUI

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    
    /// A fixed width rather than sizing to content: a two-digit day is wider than
    /// a single-digit one, so the row goes ragged every time a week crosses a month
    /// boundary — 30, 31, 1, 2, 3. Scaled rather than constant so the cell still
    /// grows with the text size.
    @ScaledMetric(relativeTo: .title3) private var cellWidth: CGFloat = 56
    
    var body: some View {
        VStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.bold))
                .foregroundColor(isSelected ? .onAccent : .textSecondary)
            // The width is fixed now, and abbreviations differ by language —
            // "sam." is wider than "сб". Shrinking is the last resort here.
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
        // Tapped through onTapGesture, so the button trait is added by hand too.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    HStack {
        CalendarDayView(date: Date(), isSelected: true)
        CalendarDayView(date: Date(), isSelected: false)
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
