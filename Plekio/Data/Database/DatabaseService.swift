//
//  DatabaseService.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.08.2026.
//

import Foundation
import OSLog
import SwiftData

/// The app's storage as one object; operations live in per-domain extensions.
/// Callers should depend on the narrow protocol they use, not on this type.
@MainActor
final class DatabaseService {

    // MARK: - Properties

    let persistence: PersistenceController

    let time: any TimeSource

    var container: ModelContainer { persistence.container }
    var context: ModelContext { persistence.context }

    var photos: any PhotoStoring { persistence.photos }

    var changes: DatabaseChangeFeed { persistence.changes }

    // MARK: - Init

    /// The on-disk store, built by `AppDependencies.live(location:)`. Throws when it can't be opened.
    init(location: StorageLocation, photos: any PhotoStoring, errors: any ErrorReporting, time: any TimeSource = SystemTime()) throws {
        persistence = try PersistenceController(location: location, photos: photos, errors: errors)
        self.time = time
    }

    /// Test-only: an in-memory container on the same schema.
    init(inMemoryForTesting: Bool, photos: any PhotoStoring, errors: any ErrorReporting, time: any TimeSource = SystemTime()) {
        persistence = PersistenceController(inMemory: inMemoryForTesting, photos: photos, errors: errors)
        self.time = time
    }

    /// In-memory store with its own temporary photo folder, for tests.
    convenience init(inMemoryForTesting: Bool) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlekioTestPhotos-\(UUID().uuidString)", isDirectory: true)
        self.init(inMemoryForTesting: inMemoryForTesting, photos: ImageCache(directory: folder), errors: AppErrorPresenter())
    }
}

// MARK: - Reading

extension DatabaseService {

    /// The one place the store is read; failures are reported, never swallowed by `try?`.
    func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> [Model] {
        do {
            let result = try context.fetch(descriptor)
            persistence.readSucceeded()
            return result
        } catch {
            persistence.reportReadFailure(error)
            return []
        }
    }
}

// MARK: - DatabaseServiceProtocol

/// Satisfied entirely by the per-domain extensions.
extension DatabaseService: DatabaseServiceProtocol {}

// MARK: - ReportReading

extension DatabaseService {

    /// Reads on BackgroundReader's context, so a long period doesn't freeze the UI.
    func reportData(for selection: ReportSelection, profile: UserProfile, now: Date) async throws -> ReportData {
        let calendar = time.calendar
        let reader = await persistence.backgroundReader()
        do {
            let data = try await reader.reportData(for: selection, profile: profile, calendar: calendar, now: now)
            persistence.readSucceeded()
            return data
        } catch {
            AppLog.storage.error("Report read failed: \(error.localizedDescription, privacy: .public)")
            throw DatabaseError.readFailed(underlying: error)
        }
    }
}

