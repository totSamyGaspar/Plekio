//
//  Untitled.swift
//  PillFlow
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

protocol OnboardingViewModelProtocol: ObservableObject {
    var currentPage: Int { get set }
    var pages: [OnboardingPage] { get }
    var isLastPage: Bool { get }
    
    func completeOnboarding()
}
