//
//  UserProfileBindings.swift
//  Plekio
//

import SwiftUI

/// The optional birthday as the two bindings a form actually needs: a switch,
/// and a date to show while the switch is on.
///
/// Written once because the settings form and the onboarding step both need it,
/// and the rule that matters — turning the switch off clears the date rather
/// than hiding it — is the kind of thing that ends up subtly different when it
/// is written twice.
///
/// Named away from `birthDate` on purpose: `$profile.birthDate` already resolves
/// through dynamic member lookup to `Binding<Date?>`, and a member of the same
/// name here would silently shadow it with a non-optional.
extension Binding where Value == UserProfile {

    var isBirthDateSet: Binding<Bool> {
        // Spelled out: inside this extension a bare `Binding` means
        // `Binding<Value>` — the profile itself — the same way `Self` would.
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

private extension Date {

    /// Where the picker opens before a birthday has been entered. Today would
    /// ask every user to scroll back three decades to reach a plausible year.
    static var defaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }
}
