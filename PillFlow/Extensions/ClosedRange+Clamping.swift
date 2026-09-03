//
//  ClosedRange+Clamping.swift
//  PillFlow
//

import Foundation

extension ClosedRange where Bound: Comparable {
    /// Pulls a value inside the range.
    ///
    /// Lives next to the ranges it is used with rather than at each call site:
    /// a bound and the clamping that enforces it drift apart the moment they
    /// are written in different places.
    func clamping(_ value: Bound) -> Bound {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
