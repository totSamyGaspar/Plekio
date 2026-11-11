//
//  WeekStrip.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI

/// The week's days under the hero card; a tap selects one.
struct WeekStrip: View {
    let dates: [Date]
    @Binding var selection: Date

    @Namespace private var daySelection

    /// The cell matching the selected day; nil once the week has moved past it.
    private var selectedDate: Date? {
        dates.first { Calendar.current.isDate($0, inSameDayAs: selection) }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(stretches: true)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                row(stretches: false)
                    .padding(.horizontal)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func row(stretches: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(dates, id: \.self) { date in
                CalendarDayView(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selection),
                    selection: daySelection,
                    stretches: stretches
                )
                .onTapGesture {
                    withMotion { selection = date }
                }
                .frame(maxWidth: stretches ? .infinity : nil)
            }
        }
        .selectionIndicator(
            following: selectedDate,
            in: daySelection,
            shape: RoundedRectangle(cornerRadius: 16),
            fill: .accentPrimary
        )
    }
}
