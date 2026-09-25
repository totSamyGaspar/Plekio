//
//  ReportSelection.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import Foundation

// MARK: - ReportSelection

/// The export screen's choices: period, courses, sections and photos.
nonisolated struct ReportSelection: Equatable {

    /// Inclusive whole days; the builder extends `to` to the end of its day.
    var from: Date
    var to: Date

    /// Empty means no courses, not all courses.
    var courseIds: Set<UUID> = []

    var sections: Set<ReportSection> = Set(ReportSection.allCases)

    /// Off by default: photos make the PDF too large for email.
    var includesPhotos = false

    func includes(_ section: ReportSection) -> Bool { sections.contains(section) }
}

// MARK: - ReportSection

nonisolated enum ReportSection: String, CaseIterable, Identifiable {

    case medications
    case bloodPressure
    case diary

    var id: String { rawValue }

    /// Same localization keys as the PDF headings, so the two stay in sync.
    var title: LocalizedStringResource {
        switch self {
        case .medications:   "Medications"
        case .bloodPressure: "Blood Pressure"
        case .diary:         "Diary"
        }
    }
}
