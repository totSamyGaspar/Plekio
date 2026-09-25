//
//  FlowLayout.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI

struct FlowLayout: Layout {

    // MARK: - Properties

    var spacing: CGFloat = 8

    // MARK: - Cache

    /// Subview sizes measured once per subview change, since SwiftUI calls
    /// `sizeThatFits`/`placeSubviews` several times per layout pass.
    struct SizeCache {
        var sizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> SizeCache {
        SizeCache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout SizeCache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    // MARK: - Layout

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

    // MARK: - Rows

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
