//
//  OnboardingPage.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

/// One slide of the onboarding carousel.
struct OnboardingPage: Identifiable {

    let id = UUID()
    let preview: Preview
    let glow: Color
    let title: LocalizedStringResource
    let description: LocalizedStringResource

    // MARK: - Preview

    /// The part of the real product each slide shows in place of an icon.
    enum Preview {
        case course, day, reminder, diary, report
    }
}
