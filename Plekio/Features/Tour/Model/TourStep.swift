//
//  TourStep.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import Foundation

/// The first-run tour: Today → create a course → log a dose.
enum TourStep: Int, CaseIterable, Equatable {
    case intro
    case createCourse
    case logDose

    /// The tab the step is shown on; the coordinator switches to it.
    var tab: AppTab {
        switch self {
        case .intro, .logDose: return .today
        case .createCourse: return .courses
        }
    }

    /// Nil: the card is centred with nothing highlighted.
    var target: TourTarget? {
        switch self {
        case .intro: return nil
        case .createCourse: return .newCourseButton
        case .logDose: return .upNextCard
        }
    }

    /// The highlighted control stays tappable and the step ends when the user uses it.
    var waitsForAction: Bool { self == .createCourse }

    var isLast: Bool { self == TourStep.allCases.last }

    var title: LocalizedStringResource {
        switch self {
        case .intro: return "Start with a course"
        case .createCourse: return "Create your first course"
        case .logDose: return "Log your doses"
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .intro:
            return "Your doses for each day will appear here. First, add the treatment you're on."
        case .createCourse:
            return "Tap + and enter the name, dates and medications. The tour continues once it's saved."
        case .logDose:
            return "Tap to log everything due now, or tick doses one by one. Made a mistake? Undo from the banner at the bottom."
        }
    }
}
