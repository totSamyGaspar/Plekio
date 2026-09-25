//
//  ClosedRange+Clamping.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.09.2026.
//

import Foundation

// MARK: - Clamping

extension ClosedRange where Bound: Comparable {
    /// Clamps `value` into the range.
    func clamping(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
