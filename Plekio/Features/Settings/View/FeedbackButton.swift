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

    /// Technical details put under the message, e.g. why the store didn't open.
    var details: String? = nil

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
        if let details {
            // Left untranslated: it's for support, below the user's own words.
            components.queryItems?.append(URLQueryItem(name: "body", value: "\n\n—\nPlekio \(AppBrand.version)\n\(details)"))
        }
        guard let url = components.url else {
            showsMailUnavailable = true
            return
        }
        openURL(url) { accepted in
            if !accepted { showsMailUnavailable = true }
        }
    }
}
