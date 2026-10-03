//
//  DataErasing.swift
//  Plekio
//
//  Created by Edward Gasparian on 03.10.2026.
//

import Foundation

/// The three deletions in Settings → Manage your data. Reminders follow on their
/// own: ReminderSyncCoordinator rebuilds the queue after every course write.
@MainActor
final class DataErasing {

    private let store: any DataErasingStore
    private let settings: SettingsStore
    private let photos: any PhotoStoring

    init(store: any DataErasingStore, settings: SettingsStore, photos: any PhotoStoring) {
        self.store = store
        self.settings = settings
        self.photos = photos
    }

    func summary() -> StoredDataSummary {
        store.storedDataSummary()
    }

    func eraseDiary() throws {
        try store.deleteDiary()
    }

    func eraseCourseHistory() throws {
        try store.deleteFinishedCourses()
    }

    /// Everything the user entered, the profile included. Settings (theme,
    /// reminders, app lock) stay: they are choices, not records.
    func eraseEverything() throws {
        try store.deleteAllRecords()
        AvatarStore.remove(settings.userProfile.avatarId, in: photos)
        settings.userProfile = .empty
    }
}
