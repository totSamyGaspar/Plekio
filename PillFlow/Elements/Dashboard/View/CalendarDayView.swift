//
//  CalendarDayView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//


import SwiftUI

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.bold))
                .foregroundColor(isSelected ? .onAccent : .textPrimary.opacity(0.5))
            
            Text(date.formatted(.dateTime.day()))
                .font(.title3.weight(.bold))
                .foregroundColor(isSelected ? .onAccent : .textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isSelected ? Color.accentPrimary : Color.textPrimary.opacity(0.05))
        .cornerRadius(16)
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
