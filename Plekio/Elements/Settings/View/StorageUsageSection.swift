//
//  StorageUsageSection.swift
//  Plekio
//

import SwiftUI

/// What the app is using on disk, in the two figures that matter.
///
/// Its own view because it is the only row here that reads the filesystem, and
/// that read belongs off the main actor.
struct StorageUsageSection: View {

    @State private var usage: StorageUsage?

    var body: some View {
        Section(header: Text("Storage").foregroundColor(.textSecondary)) {
            row("History", bytes: usage?.databaseBytes)
            row("Photos", bytes: usage?.photoBytes)
        }
        .listRowBackground(Color.appSurface)
        .task {
            let storeURL = DatabaseService.shared.persistence.storeURL
            usage = await Task.detached { StorageUsage.measure(storeURL: storeURL) }.value
        }
    }

    private func row(_ title: LocalizedStringKey, bytes: Int64?) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.textPrimary)
            Spacer()
            Text(bytes.map { $0.formatted(.byteCount(style: .file)) } ?? "—")
                .foregroundColor(.textSecondary)
                .monospacedDigit()
        }
    }
}
