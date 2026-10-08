//
//  WebLinkRow.swift
//  Plekio
//
//  Created by Edward Gasparian on 08.10.2026.
//

import SwiftUI

// MARK: - WebLinkRow

/// A Settings row that opens one of the app's web pages in Safari; styled like
/// FeedbackButton so the About section reads as one list of actions.
struct WebLinkRow: View {

    let title: LocalizedStringResource
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
            .foregroundStyle(Color.accentPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    List {
        WebLinkRow(title: "Privacy Policy", systemImage: "hand.raised", url: AppBrand.privacyPolicyURL)
    }
    .appTheme()
}
