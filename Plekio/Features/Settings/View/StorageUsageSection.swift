//
//  StorageUsageSection.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI

/// Disk usage of the database and photos, and clearing the diary.
struct StorageUsageSection: View {

    // MARK: - Types

    /// What the confirmation names, counted when the button is tapped.
    private struct DiaryClearing: Identifiable {
        let id = UUID()
        let entries: Int
        let photos: Int
    }

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies

    @State private var usage: StorageUsage?
    @State private var measurement = 0
    @State private var hasDiaryEntries = false
    @State private var pendingClearing: DiaryClearing?

    // MARK: - Body

    var body: some View {
        Section(header: Text("Storage").foregroundColor(.textSecondary)) {
            row("History", bytes: usage?.databaseBytes)
            row("Photos", bytes: usage?.photoBytes)

            Button(role: .destructive, action: askToClearDiary) {
                Label("Delete all diary entries", systemImage: "trash")
                    .foregroundColor(hasDiaryEntries ? .red : .textTertiary)
            }
            .disabled(!hasDiaryEntries)
        }
        .listRowBackground(Color.appSurface)
        .task(id: measurement) { await measure() }
        .alert(
            "Delete all diary entries?",
            isPresented: Binding(get: { pendingClearing != nil }, set: { if !$0 { pendingClearing = nil } }),
            presenting: pendingClearing
        ) { _ in
            Button("Delete", role: .destructive, action: clearDiary)
            Button("Cancel", role: .cancel) {}
        } message: { clearing in
            Text("Entries: \(clearing.entries), photos: \(clearing.photos). Blood pressure readings are kept. This can't be undone.")
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
        hasDiaryEntries = !dependencies.diaryRepository.allEntries().isEmpty
        let storeURL = dependencies.storeURL
        let photoCache = dependencies.photoCache
        usage = await Task.detached { StorageUsage.measure(storeURL: storeURL, photoCache: photoCache) }.value
    }

    private func askToClearDiary() {
        let entries = dependencies.diaryRepository.allEntries()
        guard !entries.isEmpty else { return }
        pendingClearing = DiaryClearing(entries: entries.count, photos: entries.reduce(0) { $0 + $1.photoIds.count })
    }

    private func clearDiary() {
        let repository = dependencies.diaryRepository
        guard dependencies.errorPresenter.run({ try repository.deleteAllEntries() }) else { return }
        dependencies.toasts.show(.success("Diary cleared"))
        measurement += 1
    }
}
