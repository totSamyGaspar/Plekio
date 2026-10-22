//
//  WidgetPreviews.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

#if DEBUG
import SwiftUI
import WidgetKit

// Each timeline steps through the states a widget can be in. Switch the canvas
// to dark (Canvas Device Settings) to check the other theme.

// MARK: - Up next

#Preview("Up next · small", as: .systemSmall) {
    UpNextWidget()
} timeline: {
    PreviewEntries.morning
    PreviewEntries.afternoon
    PreviewEntries.missed
    PreviewEntries.complete
    PreviewEntries.empty
    PreviewEntries.needsApp
}

#Preview("Up next · medium", as: .systemMedium) {
    UpNextWidget()
} timeline: {
    PreviewEntries.morning
    PreviewEntries.missedBehind
    PreviewEntries.missed
    PreviewEntries.complete
}

#Preview("Up next · rectangular", as: .accessoryRectangular) {
    UpNextWidget()
} timeline: {
    PreviewEntries.afternoon
    PreviewEntries.missed
    PreviewEntries.complete
}

#Preview("Up next · inline", as: .accessoryInline) {
    UpNextWidget()
} timeline: {
    PreviewEntries.afternoon
    PreviewEntries.complete
}

// MARK: - Day progress

#Preview("Day progress · small", as: .systemSmall) {
    DayProgressWidget()
} timeline: {
    PreviewEntries.afternoon
    PreviewEntries.complete
    PreviewEntries.needsApp
}

#Preview("Day progress · circular", as: .accessoryCircular) {
    DayProgressWidget()
} timeline: {
    PreviewEntries.afternoon
    PreviewEntries.complete
}

// MARK: - Today

#Preview("Today · large", as: .systemLarge) {
    TodayWidget()
} timeline: {
    PreviewEntries.afternoon
    PreviewEntries.missedBehind
    PreviewEntries.complete
    PreviewEntries.empty
}

// MARK: - Diary

#Preview("Diary · small", as: .systemSmall) {
    DiaryWidget()
} timeline: {
    PreviewEntries.morning
    PreviewEntries.diaryLogged
    PreviewEntries.diaryQuickLog
}

#Preview("Diary · medium", as: .systemMedium) {
    DiaryWidget()
} timeline: {
    PreviewEntries.morning
    PreviewEntries.diaryLogged
    PreviewEntries.diaryQuickLog
}

// MARK: - Blood pressure

#Preview("Blood pressure · small", as: .systemSmall) {
    BloodPressureWidget()
} timeline: {
    PreviewEntries.morning
    PreviewEntries.noReadings
}

#Preview("Blood pressure · medium", as: .systemMedium) {
    BloodPressureWidget()
} timeline: {
    PreviewEntries.morning
    PreviewEntries.noReadings
}

// MARK: - Low stock

#Preview("Low stock · small", as: .systemSmall) {
    LowStockWidget()
} timeline: {
    PreviewEntries.morning
    PreviewEntries.allStocked
    PreviewEntries.needsApp
}
#endif
