//
//  Route.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.06.2026.
//

import Foundation

enum Route: Hashable {
    /// An id rather than the @Model object itself: NavigationPath holds a route
    /// longer than the record lives. A course deleted while its screen sat on the
    /// stack left the path pointing at a deleted object.
    case courseDetail(courseId: UUID)
}

enum SheetRoute: Identifiable {
    
    case newTreatment
    /// Confirm the open doses of one slot — from a tapped reminder or from the
    /// dashboard. Data only: what the buttons do is DoseSheetActions', not
    /// carried in the route as closures.
    case takePill(pills: [PillDose])
    case diaryCheckIn
    /// The blood-pressure entry form. Presented from MainTabView rather than
    /// from the diary screen so a reminder can open it on a cold launch, where
    /// the diary tab is not in the hierarchy yet.
    case bloodPressureEntry

    // Identifiable is required for .sheet(item:).
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
