//
//  TipJarSection.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.09.2026.
//

import SwiftUI

/// One "Support the project" button; the tips open in a dialog. Hidden when the
/// store offers none (offline, not set up). The parent loads `options`: a task on
/// an empty section would never run.
struct TipJarSection: View {

    @Environment(AppDependencies.self) private var dependencies

    let options: [TipOption]

    @State private var showsTips = false
    /// Set while a purchase is in progress; the button shows progress and is disabled.
    @State private var isGiving = false

    var body: some View {
        if !options.isEmpty {
            Section {
                Button { showsTips = true } label: {
                    HStack {
                        Label("Support the project", systemImage: "cup.and.saucer.fill")
                            .foregroundColor(.accentPrimary)
                        Spacer()
                        if isGiving { ProgressView() }
                    }
                }
                .disabled(isGiving)
            }
            .listRowBackground(Color.appSurface)
            .confirmationDialog("Support the project", isPresented: $showsTips, titleVisibility: .visible) {
                ForEach(options) { option in
                    Button {
                        Task { await give(option.tip) }
                    } label: {
                        Text(option.tip.title) + Text(verbatim: " — \(option.displayPrice)")
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Plekio is free and has no ads. If it helps you, you can leave a tip.")
            }
        }
    }

    private func give(_ tip: TipSize) async {
        isGiving = true
        defer { isGiving = false }
        do {
            switch try await dependencies.tipJar.give(tip) {
            case .thanked: dependencies.toasts.show(.success("Thank you for supporting Plekio!"))
            case .pending: dependencies.toasts.show(.info("Your tip is waiting for approval."))
            case .cancelled: break
            }
        } catch {
            dependencies.errorPresenter.report(error as? TipFailed ?? .unavailable)
        }
    }
}
