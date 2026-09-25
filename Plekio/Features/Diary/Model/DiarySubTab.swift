//
//  DiarySubTab.swift
//  Plekio
//
//  Created by Edward Gasparian on 04.09.2026.
//

import SwiftUI

// MARK: - DiarySubTab

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
