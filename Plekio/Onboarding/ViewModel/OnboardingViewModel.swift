//
//  OnboardingViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

/// The order is the story: set a course up, use it through the day, answer
/// the reminder where it lands, record more than pills, and finally hand the whole
/// thing to a doctor. The last slide is the payoff, which is why it is last.
final class OnboardingViewModel: OnboardingViewModelProtocol {

    @Published var currentPage = 0

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var pages: [OnboardingPage] { Self.allPages }

    /// Static so previews can show a page without building the view model.
    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            preview: .course,
            glow: .accentPrimary,
            title: "A course in a minute",
            description: "Name, dose, time and how often. Every three days or twice a day — the schedule works itself out."
        ),
        OnboardingPage(
            preview: .day,
            glow: .accentPrimary,
            title: "The day as one list",
            description: "Morning, afternoon and evening apart. One tap logs a dose, another takes it back."
        ),
        OnboardingPage(
            preview: .reminder,
            glow: .warmAccent,
            title: "Straight from the reminder",
            description: "Hold the reminder to take a dose, snooze it or skip it — what is left in the pack goes down by itself."
        ),
        OnboardingPage(
            preview: .diary,
            glow: .milestonePurple,
            title: "Not only pills",
            description: "Well-being, sleep, blood pressure and progress photos — so you can see whether the treatment is working."
        ),
        OnboardingPage(
            preview: .report,
            glow: .accentPrimary,
            title: "One file for the doctor",
            description: "Pick the period and the sections, and the app builds a PDF you can send by messenger or mail."
        )
    ]

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    func completeOnboarding() {
        settings.hasSeenOnboarding = true
    }
}
