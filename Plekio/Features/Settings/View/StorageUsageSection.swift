//
//  StorageUsageSection.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI

/// Disk usage of the database and photos; measured off the main actor.
struct StorageUsageSection: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies

    @State private var usage: StorageUsage?

    // MARK: - Body

    var body: some View {
        Section(header: Text("Storage").foregroundColor(.textSecondary)) {
            row("History", bytes: usage?.databaseBytes)
            row("Photos", bytes: usage?.photoBytes)
        }
        .listRowBackground(Color.appSurface)
        .task {
            let storeURL = dependencies.storeURL
            let photoCache = dependencies.photoCache
            usage = await Task.detached { StorageUsage.measure(storeURL: storeURL, photoCache: photoCache) }.value
        }
    }

    // MARK: - Subviews

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
