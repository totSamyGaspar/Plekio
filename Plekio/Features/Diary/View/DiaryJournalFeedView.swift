//
//  DiaryJournalFeedView.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI

/// Searchable, filterable list of diary entries.
struct DiaryJournalFeedView: View {

    // MARK: - Properties

    let entries: [DiaryEntrySnapshot]
    let onEdit: (DiaryEntrySnapshot) -> Void
    let onDelete: (DiaryEntrySnapshot) -> Void

    @State private var searchText = ""
    @State private var moodFilter: DiaryMood?
    @State private var photosOnlyFilter = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            searchFilterBar

            if filteredEntries.isEmpty {
                EmptyStateView(
                    icon: "text.book.closed.fill",
                    title: entries.isEmpty ? "No check-ins yet" : "No entries match your filters"
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(filteredEntries) { entry in
                        DiaryEntryRowView(
                            entry: entry,
                            onEdit: { onEdit(entry) },
                            onDelete: { onDelete(entry) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Filtering

    private var filteredEntries: [DiaryEntrySnapshot] {
        entries.filter { entry in
            let matchesSearch = searchText.isEmpty
            || entry.physicalSummary.localizedCaseInsensitiveContains(searchText)
            || entry.reflectionNotes.localizedCaseInsensitiveContains(searchText)
            let matchesMood = moodFilter == nil || entry.moodLabel == moodFilter?.rawValue
            let matchesPhotos = !photosOnlyFilter || !entry.photoIds.isEmpty
            return matchesSearch && matchesMood && matchesPhotos
        }
    }

    // MARK: - Subviews

    private var searchFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textTertiary)
                TextField("Search notes", text: $searchText)
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appSurface)
            .cornerRadius(12)

            HStack(spacing: 10) {
                Menu {
                    Button("All Moods") { moodFilter = nil }
                    ForEach(DiaryMood.allCases) { mood in
                        Button { moodFilter = mood } label: {
                            Text(verbatim: "\(mood.emoji) ") + Text(mood.title)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(moodFilter?.title ?? "All Moods")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appSurface)
                    .cornerRadius(10)
                }

                Button {
                    photosOnlyFilter.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("With Photos")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(photosOnlyFilter ? Color.onAccent : .textPrimary.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(photosOnlyFilter ? Color.accentPrimary : Color.appSurface)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }
}
