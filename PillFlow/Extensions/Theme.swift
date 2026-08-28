//
//  Theme.swift
//  PillFlow
//
//  Created by Edward Gasparian on 11.06.2026.
//

import SwiftUI

extension Color {
    /// Deep dark background used throughout the app
    static let bgDark = Color(red: 0.06, green: 0.08, blue: 0.12)

    /// Color for cards and panels on the dark background
    static let cardDark = Color(red: 0.11, green: 0.13, blue: 0.19)

    /// The primary accent. It used to be referenced under two names —
    /// `Color.neonMint` and plain `Color.mint` — mixed together, sometimes on
    /// adjacent lines, so changing the accent in one place no longer worked.
    /// This is now the only name for it.
    static let neonMint = Color.mint

    /// Companion to the accent for gradients (progress ring, hero card).
    static let neonTeal = Color.teal

    /// Accent for diary milestone tags. The literal was duplicated in three files.
    static let milestonePurple = Color(red: 0.7, green: 0.4, blue: 0.9)

    /// Background and accent for the low-stock warning.
    static let warningBg = Color(red: 0.2, green: 0.05, blue: 0.08)
    static let warningAccent = Color(red: 0.9, green: 0.4, blue: 0.4)
}
