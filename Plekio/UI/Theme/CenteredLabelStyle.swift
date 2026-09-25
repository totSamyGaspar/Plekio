//
//  CenteredLabelStyle.swift
//  Plekio
//
//  Created by Edward Gasparian on 29.08.2026.
//

import SwiftUI

// MARK: - CenteredLabelStyle

/// A `Label` whose icon is centred against a multi-line title (the stock style
/// aligns it to the first line).
struct CenteredLabelStyle: LabelStyle {
    var spacing: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - LabelStyle + centered

extension LabelStyle where Self == CenteredLabelStyle {
    static var centered: CenteredLabelStyle { CenteredLabelStyle() }
}
