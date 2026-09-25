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

    @Published var currentPage = 0

    // The real pages: a preview of the carousel is worth nothing if the slides
    // in it are not the ones that ship.
    let pages = OnboardingViewModel.allPages

    var isLastPage: Bool { currentPage == pages.count - 1 }

    func completeOnboarding() {}
}

#endif
