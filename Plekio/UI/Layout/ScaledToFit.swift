//
//  ScaledToFit.swift
//  Plekio
//
//  Created by Edward Gasparian on 08.11.2026.
//

import SwiftUI

/// Draws `content` at its natural size, scaled to fit the space offered, up to `maxScale`.
struct ScaledToFit<Content: View>: View {

    var maxScale: CGFloat = 1
    @ViewBuilder let content: Content

    @State private var natural: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            content
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { natural = $0 }
                .scaleEffect(scale(in: proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func scale(in space: CGSize) -> CGFloat {
        // Never zero: a zero scale is a singular transform, and CoreGraphics logs NaN.
        guard natural.width > 0, natural.height > 0, space.width > 0, space.height > 0 else { return 1 }
        return min(maxScale, space.width / natural.width, space.height / natural.height)
    }
}
