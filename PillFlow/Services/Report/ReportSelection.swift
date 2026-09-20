//
//  ReportSelection.swift
//  PillFlow
//

import Foundation

/// What the user asked the document to contain.
///
/// Everything the export screen collects and nothing else: the builder turns
/// this into data, the renderer draws that data, and neither of them has to
/// know what a checkbox looked like.
nonisolated struct ReportSelection: Equatable {

    /// Inclusive, in whole days. `to` is normalised to the end of its day by
    /// the builder, so a report "to the 14th" contains the 14th.
    var from: Date
    var to: Date

    /// Which courses to include. Empty means the medication section has nothing
    /// to show — it is a selection of none, not a selection of all.
    var courseIds: Set<UUID> = []

    var sections: Set<ReportSection> = Set(ReportSection.allCases)

    /// Off by default. Diary photos are what turns a document that fits in an
    /// email into one that does not.
    var includesPhotos = false

    func includes(_ section: ReportSection) -> Bool { sections.contains(section) }
}

nonisolated enum ReportSection: String, CaseIterable, Identifiable {

    case medications
    case bloodPressure
    case diary

    var id: String { rawValue }

    /// The same keys the sections carry inside the document and the same ones
    /// the rest of the app already uses, so a heading in the PDF and its
    /// checkbox on the export screen cannot drift apart.
    var title: LocalizedStringResource {
        switch self {
        case .medications:   "Medications"
        case .bloodPressure: "Blood Pressure"
        case .diary:         "Diary"
        }
    }
}
