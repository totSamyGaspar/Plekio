//
//  Route.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.06.2026.
//

import Foundation

// MARK: - Route

enum Route: Hashable {
    /// An id, not the @Model: NavigationPath can outlive a deleted record.
    case courseDetail(courseId: UUID)
}

// MARK: - SheetRoute

enum SheetRoute: Identifiable {

    // MARK: - Cases

    case newTreatment
    /// Confirms the open doses of one slot. Data only; actions live in DoseSheetActions.
    case takePill(pills: [PillDose])
    case diaryCheckIn
    /// Presented from MainTabView so a reminder can open it on a cold launch.
    case bloodPressureEntry

    // MARK: - Identifiable

    var id: String {
        switch self {
        case .newTreatment:
            return "newTreatment"
        case .takePill(let pills):
            return "takePill-" + pills.map(\.id).joined(separator: "-")
        case .diaryCheckIn:
            return "diaryCheckIn"
        case .bloodPressureEntry:
            return "bloodPressureEntry"
        }
    }
}
