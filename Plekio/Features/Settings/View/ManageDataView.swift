//
//  ManageDataView.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.10.2026.
//

import SwiftUI

/// Settings → Manage your data: three deletions, each behind a warning that it
/// can't be undone. An action with nothing to delete is disabled.
struct ManageDataView: View {

    // MARK: - Erasure

    private enum Erasure: Identifiable {
        case diary, courseHistory, everything

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .diary: "Delete all diary entries"
            case .courseHistory: "Clear course history"
            case .everything: "Delete all data"
            }
        }

        var question: LocalizedStringKey {
            switch self {
            case .diary: "Delete all diary entries?"
            case .courseHistory: "Clear course history?"
            case .everything: "Delete all data?"
            }
        }

        var scope: LocalizedStringKey {
            switch self {
            case .diary: "Diary entries, their photos and blood pressure readings."
            case .courseHistory: "Finished courses with their dose history. Running courses stay."
            case .everything: "All courses, doses, diary records, photos and your profile. App settings stay."
            }
        }

        var done: LocalizedStringResource {
            switch self {
            case .diary: "Diary cleared"
            case .courseHistory: "Course history cleared"
            case .everything: "All data deleted"
            }
        }

        var systemImage: String {
            switch self {
            case .diary: "book.closed"
            case .courseHistory: "clock.arrow.circlepath"
            case .everything: "trash"
            }
        }
    }

    // MARK: - Properties

    @Environment(AppDependencies.self) private var dependencies

    @State private var summary = StoredDataSummary()
    @State private var pending: Erasure?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            List {
                section(.diary, isEnabled: summary.diaryRecords > 0)
                section(.courseHistory, isEnabled: summary.finishedCourses > 0)
                section(.everything, isEnabled: !summary.isEmpty)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Manage your data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { summary = dependencies.dataErasing.summary() }
        .alert(
            pending?.question ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { erasure in
            Button("Delete", role: .destructive) { erase(erasure) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Deleted data can't be restored.")
        }
    }

    private func section(_ erasure: Erasure, isEnabled: Bool) -> some View {
        Section {
            Button(role: .destructive) { pending = erasure } label: {
                Label(erasure.title, systemImage: erasure.systemImage)
                    .foregroundColor(isEnabled ? .red : .textTertiary)
            }
            .disabled(!isEnabled)
        } footer: {
            Text(erasure.scope).foregroundColor(.textSecondary)
        }
        .listRowBackground(Color.appSurface)
    }

    // MARK: - Actions

    private func erase(_ erasure: Erasure) {
        let erasing = dependencies.dataErasing
        let succeeded = dependencies.errorPresenter.run {
            switch erasure {
            case .diary: try erasing.eraseDiary()
            case .courseHistory: try erasing.eraseCourseHistory()
            case .everything: try erasing.eraseEverything()
            }
        }
        guard succeeded else { return }
        dependencies.toasts.show(.success(erasure.done))
        summary = erasing.summary()
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        ManageDataView()
    }
    .environment(AppDependencies.preview)
}
#endif
