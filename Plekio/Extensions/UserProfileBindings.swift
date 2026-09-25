//
//  UserProfileBindings.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI

// MARK: - Birthday bindings

/// Toggle + date bindings for the optional birthday; switching off clears it.
/// Not named `birthDate`: that would shadow the dynamic-member `Binding<Date?>`.
extension Binding where Value == UserProfile {

    var isBirthDateSet: Binding<Bool> {
        // Explicit type: a bare `Binding` here means `Binding<UserProfile>`.
        Binding<Bool>(
            get: { wrappedValue.birthDate != nil },
            set: { wrappedValue.birthDate = $0 ? (wrappedValue.birthDate ?? .defaultBirthDate) : nil }
        )
    }

    var birthDateOrDefault: Binding<Date> {
        Binding<Date>(
            get: { wrappedValue.birthDate ?? .defaultBirthDate },
            set: { wrappedValue.birthDate = $0 }
        )
    }
}

// MARK: - Helpers

private extension Date {

    /// Initial picker date: 30 years ago, so users need not scroll far.
    static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }
}
