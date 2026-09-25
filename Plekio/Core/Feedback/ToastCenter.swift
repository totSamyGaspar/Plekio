//
//  ToastCenter.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import Observation
import UIKit

// MARK: - Toast

/// A short, non-blocking confirmation or hint. Errors go to the alert, not here.
struct Toast: Identifiable, Equatable {

    enum Style {
        /// Something the user did worked.
        case success
        /// A hint: why nothing happened, or what to do first.
        case info
    }

    let id = UUID()
    let style: Style
    let message: LocalizedStringResource

    static func success(_ message: LocalizedStringResource) -> Toast {
        Toast(style: .success, message: message)
    }

    static func info(_ message: LocalizedStringResource) -> Toast {
        Toast(style: .info, message: message)
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

// MARK: - ToastCenter

/// The app's one toast slot, shown by MainTabView above every screen, so a toast
/// raised by a sheet that is closing still reaches the user.
@Observable
@MainActor
final class ToastCenter {

    // MARK: - Properties

    private(set) var current: Toast?

    @ObservationIgnored private var hideTask: Task<Void, Never>?

    /// Long enough to read a sentence; a newer toast replaces the current one.
    static let visibleDuration: Duration = .seconds(3)

    // MARK: - Init

    init() {}

    // MARK: - Actions

    func show(_ toast: Toast) {
        current = toast

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(toast.style == .success ? .success : .warning)

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else { return }
            self?.dismiss(toast)
        }
    }

    /// Hides `toast` only if it is still the one showing.
    func dismiss(_ toast: Toast) {
        guard current == toast else { return }
        current = nil
    }
}
