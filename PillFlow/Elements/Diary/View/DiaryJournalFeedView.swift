//
//  DiaryJournalFeedView.swift
//  PillFlow
//
//  Created by Edward Gasparian on 24.08.2026.
//
//  The diary's "Journal Feed" tab: search, filters and the entry list. Split
//  out of DiaryView, which ran past 1400 lines with the gallery, the trends
//  and two standalone screens in it.
//
//  Filter state lives here — nothing outside this tab needs it.
//

import SwiftUI

struct DiaryJournalFeedView: View {
    let entries: [DiaryEntry]
    let onEdit: (DiaryEntry) -> Void
    let onDelete: (DiaryEntry) -> Void

    @State private var searchText = ""
    @State private var moodFilter: DiaryMood?
    @State private var photosOnlyFilter = false

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

    private var filteredEntries: [DiaryEntry] {
        entries.filter { entry in
            let matchesSearch = searchText.isEmpty
                || entry.physicalSummary.localizedCaseInsensitiveContains(searchText)
                || entry.reflectionNotes.localizedCaseInsensitiveContains(searchText)
            let matchesMood = moodFilter == nil || entry.moodLabel == moodFilter?.rawValue
            let matchesPhotos = !photosOnlyFilter || !entry.photoIds.isEmpty
            return matchesSearch && matchesMood && matchesPhotos
        }
    }

    private var searchFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textPrimary.opacity(0.4))
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
                        // The emoji is verbatim; only the name goes through localization.
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
