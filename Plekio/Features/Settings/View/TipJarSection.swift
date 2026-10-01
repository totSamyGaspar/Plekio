//
//  TipJarSection.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.09.2026.
//

import SwiftUI

/// One "Support the project" button that opens TipJarSheet. Hidden when the store
/// offers no tips (offline, not set up). The parent loads `options`: a task on an
/// empty section would never run.
struct TipJarSection: View {

    @Environment(AppDependencies.self) private var dependencies

    let options: [TipOption]

    @State private var showsTips = false

    var body: some View {
        if !options.isEmpty {
            Section {
                Button { showsTips = true } label: {
                    Label("Support the project", systemImage: "cup.and.saucer.fill")
                        .foregroundColor(.accentPrimary)
                }
            }
            .listRowBackground(Color.appSurface)
            .sheet(isPresented: $showsTips) {
                TipJarSheet(options: options, give: give)
            }
        }
    }

    /// True when the sheet should close: the tip went through, awaits approval, or
    /// failed (the alert is shown by MainTabView, under the sheet).
    private func give(_ tip: TipSize) async -> Bool {
        do {
            switch try await dependencies.tipJar.give(tip) {
            case .thanked:
                dependencies.toasts.show(.success("Thank you for supporting Plekio!"))
                return true
            case .pending:
                dependencies.toasts.show(.info("Your tip is waiting for approval."))
                return true
            case .cancelled:
                return false
            }
        } catch {
            dependencies.errorPresenter.report(error as? TipFailed ?? .unavailable)
            return true
        }
    }
}
