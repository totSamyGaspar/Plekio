//
//  UITestingSeed.swift
//  Plekio
//
//  Created by Edward Gasparian on 18.11.2026.
//

#if DEBUG
import Foundation

// MARK: - UITestingSeed

/// Writes a seed's data through the same store calls the app uses, so tests see
/// what a user would after entering it by hand.
enum UITestingSeed {

    /// Course names and medication names the UI tests look for.
    enum Names {
        static let course = "Vitamins"
        /// At 09:00.
        static let morning = "Omega-3"
        /// At the minute the app was launched.
        static let dueNow = "Vitamin D3"
    }

    static func apply(_ seed: UITestingLaunch.Seed, to store: any CourseStoring, time: any TimeSource) {
        switch seed {
        case .empty, .onboarding:
            return
        case .today:
            seedToday(store, time: time)
        }
    }

    // MARK: - Seeds

    /// Started yesterday, so the course is running whatever time the test runs at.
    /// Dates follow the launch's `TimeSource`, the same clock the screens and forms read.
    private static func seedToday(_ store: any CourseStoring, time: any TimeSource) {
        let calendar = time.calendar
        let today = calendar.startOfDay(for: time.now)
        guard let start = calendar.date(byAdding: .day, value: -1, to: today),
              let end = calendar.date(byAdding: .day, value: 6, to: today)
        else { fatalError("UI-testing seed: couldn't build the course dates") }

        do {
            try store.saveCourse(
                name: Names.course,
                startDate: start,
                endDate: end,
                drafts: [
                    MedicationDraft(name: Names.morning, minutesOfDay: [9 * 60], mealTiming: .afterMeal),
                    // Due this minute, so Today always has an Up next card: a dose stays
                    // open for an hour after its time. A fixed time would leave the card
                    // missing for tests run late in the evening.
                    MedicationDraft(
                        name: Names.dueNow,
                        minutesOfDay: [MinuteOfDay.of(time.now, calendar: calendar)],
                        mealTiming: .withMeal
                    ),
                ]
            )
        } catch {
            // A seed that didn't land would make every test fail for the wrong reason.
            fatalError("UI-testing seed failed: \(error)")
        }
    }
}
#endif
