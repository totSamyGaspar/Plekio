//
//  FeedbackButton.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.09.2026.
//

import SwiftUI
import UIKit

struct FeedbackButton: View {
    @Environment(\.openURL) private var openURL
    @State private var showsMailUnavailable = false

    private let email = "plekio.support@gmail.com"

    var body: some View {
        Button(action: composeFeedback) {
            Label("Send feedback", systemImage: "envelope")
                .foregroundStyle(Color.accentPrimary)
        }
        .alert("Could not open email", isPresented: $showsMailUnavailable) {
            Button("Copy email address") {
                UIPasteboard.general.string = email
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Open your email app and write to:") + Text(verbatim: "\n\(email)")
        }
    }

    private func composeFeedback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "Plekio feedback"))
        ]
        guard let url = components.url else {
            showsMailUnavailable = true
            return
        }
        openURL(url) { accepted in
            if !accepted { showsMailUnavailable = true }
        }
    }
}
