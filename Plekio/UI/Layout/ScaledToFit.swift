//
//  ScaledToFit.swift
//  Plekio
//
//  Created by Edward Gasparian on 08.11.2026.
//

import SwiftUI

/// Draws `content` at its natural size, scaled down (never up) to fit the space offered.
struct ScaledToFit<Content: View>: View {

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
        guard natural.width > 0, natural.height > 0 else { return 1 }
        return min(1, space.width / natural.width, space.height / natural.height)
    }
}
