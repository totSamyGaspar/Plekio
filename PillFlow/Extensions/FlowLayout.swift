//
//  FlowLayout.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  A simple left-to-right, top-to-bottom wrapping layout (a "flow"/"tag cloud"
//  layout) for rows of variable-width chips — plain HStack doesn't wrap on its
//  own. Used by the Diary check-in screen for symptom and milestone tags.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    /// The measured size of each chip.
    ///
    /// SwiftUI calls `sizeThatFits` and `placeSubviews` several times per layout
    /// pass. Asking every subview for its size in each of them is a text
    /// measurement per tag per call — in a scrolling feed of entries, thousands of
    /// them for chips whose size never changes. Measured once here instead,
    /// and again only when the subviews themselves change.
    struct SizeCache {
        var sizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> SizeCache {
        SizeCache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout SizeCache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout SizeCache) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, sizes: cache.sizes)
        let height = rows.reduce(CGFloat(0)) { partial, row in
            partial + row.maxHeight + (partial > 0 ? spacing : 0)
        }
        let width = maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout SizeCache) {
        let rows = computeRows(maxWidth: bounds.width, sizes: cache.sizes)

        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = cache.sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var maxHeight: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, sizes: [CGSize]) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in sizes.indices {
            let size = sizes[index]
            let addedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if addedWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.indices.append(index)
            current.width = current.indices.count == 1 ? size.width : current.width + spacing + size.width
            current.maxHeight = max(current.maxHeight, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
