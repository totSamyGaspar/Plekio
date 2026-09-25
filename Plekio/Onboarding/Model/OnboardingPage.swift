//
//  OnboardingPage.swift
//  Plekio
//
//  Created by Edward Gasparian on 02.05.2026.
//

import SwiftUI

/// One slide of the carousel.
///
/// The illustration is named, not drawn, here: a page is content, and which
/// slice of the interface stands beside the words is a view's business.
struct OnboardingPage: Identifiable {

    let id = UUID()
    let preview: Preview
    let glow: Color
    let title: LocalizedStringResource
    let description: LocalizedStringResource

    /// The part of the real product each slide shows in place of an icon.
    enum Preview {
        case course, day, reminder, diary, report
    }
}
