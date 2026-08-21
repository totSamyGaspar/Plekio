//
//  OnboardingViewModel.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

// MARK: - Реальная ViewModel
final class OnboardingViewModel: OnboardingViewModelProtocol {
    @Published var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(imageSystemName: "pills.fill", imageColor: .mint, title: "Create treatment courses", description: "Easily add medications, adjust dosage, and set a convenient schedule in a few taps."),
        OnboardingPage(imageSystemName: "bell.badge.fill", imageColor: .orange, title: "Smart reminders", description: "Get timely notifications and log your medication right from the lock screen."),
        OnboardingPage(imageSystemName: "calendar.day.timeline.left", imageColor: .blue, title: "Your daily timeline", description: "Track your progress, build a healthy habit, and never miss a single pill.")
    ]
    
    var isLastPage: Bool {
        currentPage == pages.count - 1
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
    }
}
