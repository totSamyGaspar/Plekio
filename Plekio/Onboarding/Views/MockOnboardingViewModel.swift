//
//  MockOnboardingViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

// Preview-only, and behind #if DEBUG: unguarded, a mock in the main target
// ships in the release binary.
#if DEBUG
final class MockOnboardingViewModel: OnboardingViewModelProtocol {
    @Published var currentPage = 2
    
    let pages: [OnboardingPage] = [
        OnboardingPage(imageSystemName: "questionmark", imageColor: .gray, title: "Mock", description: "Mock data")
    ]
    
    var isLastPage: Bool = true
    
    func completeOnboarding() {}
}

#endif
