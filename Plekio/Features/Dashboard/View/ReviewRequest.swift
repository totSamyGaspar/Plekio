//
//  ReviewRequest.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.10.2026.
//

import StoreKit
import SwiftUI

// MARK: - ReviewRequest

/// Asks for an App Store rating right after the user takes a dose, once
/// ReviewPrompt says it's time. The dialog itself is the system's: Apple
/// doesn't allow a custom one, and it can't be styled.
private struct ReviewRequest: ViewModifier {

    /// Let the check mark and the haptic land before the dialog covers them.
    private static let delay: Duration = .seconds(1)

    let pills: [PillDose]

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.onChange(of: DoseFeedback.statuses(of: pills)) { old, new in
            guard DoseFeedback.tookADose(from: old, to: new),
                  dependencies.reviewPrompt.takeRequestIfDue()
            else { return }

            Task {
                try? await Task.sleep(for: Self.delay)
                requestReview()
            }
        }
    }
}

// MARK: - View+ReviewRequest

extension View {

    /// Asks for a rating after a dose among `pills` is taken; see ReviewPrompt for when.
    func requestsReviewAfterTaking(_ pills: [PillDose]) -> some View {
        modifier(ReviewRequest(pills: pills))
    }
}
