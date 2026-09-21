//
//  DiarySubTab.swift
//  Plekio
//
//  Lifted out of DiaryView so AppRouter can name a sub-tab: a blood-pressure
//  reminder has to land on Mood & Trends, where the readings are, and routing
//  cannot ask a view about a type private to it.
//

import SwiftUI

enum DiarySubTab: String, CaseIterable, Identifiable {
    case journalFeed, progressGallery, moodTrends

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .journalFeed:     return "Journal Feed"
        case .progressGallery: return "Progress Gallery"
        case .moodTrends:      return "Mood & Trends"
        }
    }

    var icon: String {
        switch self {
        case .journalFeed:     return "doc.text.fill"
        case .progressGallery: return "photo.stack.fill"
        case .moodTrends:      return "chart.line.uptrend.xyaxis"
        }
    }
}
