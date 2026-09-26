//
//  ToastView.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import SwiftUI

// MARK: - ToastView

struct ToastView: View {

    // MARK: - Properties

    let toast: Toast

    private var icon: String {
        toast.style == .success ? "checkmark.circle.fill" : "info.circle.fill"
    }

    private var tint: Color {
        toast.style == .success ? .accentPrimary : .warmAccent
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(tint)
                .accessibilityHidden(true)
            Text(toast.message)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.appSurface)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Toast Overlay

extension View {

    /// Shows `center`'s toast at the top; tap to dismiss. VoiceOver reads it out.
    func toastOverlay(_ center: ToastCenter) -> some View {
        overlay(alignment: .top) {
            if let toast = center.current {
                ToastView(toast: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { center.dismiss(toast) }
                    .onAppear {
                        AccessibilityNotification.Announcement(String(localized: toast.message)).post()
                    }
                    .id(toast.id)
            }
        }
        .motion(Motion.standard, value: center.current)
        .sensoryFeedback(trigger: center.current) { _, new in new?.style.feedback }
    }
}

// MARK: - Toast.Style+Feedback

extension Toast.Style {

    var feedback: SensoryFeedback {
        switch self {
        case .success: return .success
        case .info: return .warning
        }
    }
}
