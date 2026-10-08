//
//  StorageUsageSection.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI

/// Disk usage of the database and photos, and the way into Manage your data.
struct StorageUsageSection: View {

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.databaseChanges) private var databaseChanges

    @State private var usage: StorageUsage?

    // MARK: - Body

    var body: some View {
        Section(header: Text("Your data").foregroundColor(.textSecondary)) {
            NavigationLink {
                ManageDataView()
            } label: {
                Label("Manage your data", systemImage: "externaldrive")
                    .foregroundColor(.textPrimary)
            }
        }
        .listRowBackground(Color.appSurface)
        .task { await measure() }
        // Deletions happen on the pushed screen; re-measure when they land.
        .onReceive(databaseChanges.publisher(for: [.courses, .diary])) { _ in
            Task { await measure() }
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

    // MARK: - Actions

    private func measure() async {
        let storeURL = dependencies.storeURL
        let photoCache = dependencies.photoCache
        usage = await Task.detached { StorageUsage.measure(storeURL: storeURL, photoCache: photoCache) }.value
    }
}


// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        List {
            StorageUsageSection()
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .appTheme()
    }
    .environment(AppDependencies.preview)
    .environment(\.databaseChanges, AppDependencies.preview.database.changes)
}
#endif
