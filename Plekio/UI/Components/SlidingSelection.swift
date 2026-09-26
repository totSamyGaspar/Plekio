//
//  SlidingSelection.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

// One indicator view lives behind the whole group and follows the selected item's
// frame, so it slides instead of disappearing from one item and appearing in another.
// The selection change must happen inside an animation.

extension View {

    /// Marks an item of the group as a place the indicator can move to.
    func selectionAnchor<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        matchedGeometryEffect(id: id, in: namespace, isSource: true)
    }

    /// Draws the indicator behind the group, over the anchor for `selected`.
    /// Nil (or an id with no anchor on screen) draws nothing.
    func selectionIndicator<ID: Hashable, S: Shape>(
        following selected: ID?,
        in namespace: Namespace.ID,
        shape: S,
        fill: Color
    ) -> some View {
        background {
            if let selected {
                shape
                    .fill(fill)
                    .matchedGeometryEffect(id: selected, in: namespace, isSource: false)
            }
        }
    }
}
