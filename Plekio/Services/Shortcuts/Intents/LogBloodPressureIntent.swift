//
//  LogBloodPressureIntent.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.10.2026.
//

import AppIntents

/// "Log my blood pressure": Siri asks for the two numbers. A phrase can't carry
/// them, as App Shortcut phrases only take entity and enum parameters. Pulse is
/// optional and Siri doesn't ask for it; it can be set in a Shortcuts action.
///
/// Not `nonisolated` as a whole: the @Parameter properties can't be. What the
/// protocol reads without an actor is marked one by one.
struct LogBloodPressureIntent: AppIntent {

    nonisolated static let title: LocalizedStringResource = "Log blood pressure"
    nonisolated static let description = IntentDescription("Records a blood pressure reading in the diary.")
    nonisolated static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Systolic", requestValueDialog: IntentDialog("What's the upper number?"))
    var systolic: Int

    @Parameter(title: "Diastolic", requestValueDialog: IntentDialog("What's the lower number?"))
    var diastolic: Int

    @Parameter(title: "Pulse")
    var pulse: Int?

    nonisolated init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ShortcutBloodPressureActions.log(systolic: systolic, diastolic: diastolic, pulse: pulse)
        return .result(dialog: IntentDialog(ShortcutDialog.readingSaved(
            systolic: systolic, diastolic: diastolic, hidesDetails: ShortcutContext.hidesDetails
        )))
    }
}
