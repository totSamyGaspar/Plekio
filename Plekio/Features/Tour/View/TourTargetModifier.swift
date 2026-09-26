//
//  TourTargetModifier.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

// MARK: - View+TourTarget

extension View {

    /// Reports this view's on-screen frame to the tour, so a step can point at it.
    func tourTarget(_ target: TourTarget) -> some View {
        modifier(TourTargetModifier(target: target))
    }
}

// MARK: - TourTargetModifier

struct TourTargetModifier: ViewModifier {
    let target: TourTarget
    @Environment(AppDependencies.self) private var dependencies

    func body(content: Content) -> some View {
        content
            // Global frames: the overlay sits above every tab, outside this view's hierarchy.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                dependencies.tour.update(target, frame: frame)
            }
            .onDisappear { dependencies.tour.update(target, frame: nil) }
    }
}
