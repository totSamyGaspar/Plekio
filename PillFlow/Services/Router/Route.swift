//
//  Route.swift
//  PillFlow
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
    case takePill(pills: [PillDose], onTake: () -> Void, onSkip: () -> Void)
    case diaryCheckIn

    // Identifiable is required for .sheet(item:).
    var id: String {
        switch self {
        case .newTreatment:
            return "newTreatment"
        case .takePill(let pills, _, _):
            return "takePill-" + pills.map(\.id).joined(separator: "-")
        case .diaryCheckIn:
            return "diaryCheckIn"
        }
    }
}
