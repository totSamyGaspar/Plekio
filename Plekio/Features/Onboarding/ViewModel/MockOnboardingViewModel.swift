//
//  MockOnboardingViewModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI
import Combine

// Behind #if DEBUG so the mock does not ship in the release binary.
#if DEBUG
final class MockOnboardingViewModel: OnboardingViewModelProtocol {

    // MARK: - Properties

    @Published var currentPage = 0

    // The real pages, so previews show the slides that ship.
    let pages = OnboardingViewModel.allPages

    var isLastPage: Bool { currentPage == pages.count - 1 }

    // MARK: - Actions

    func completeOnboarding() {}
}

#endif
