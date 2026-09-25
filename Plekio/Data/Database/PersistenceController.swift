//
//  PersistenceController.swift
//  Plekio
//
//  Created by Edward Gasparian on 14.09.2026.
//

import Foundation
import OSLog
import SwiftData

/// Container, context and the one commit point. Invariants: a failed save rolls
/// back and rethrows; every write clears the day cache and announces its changes.
@MainActor
final class PersistenceController {

    // MARK: - Properties

    let container: ModelContainer
    let context: ModelContext

    /// Photo files live beside the store, not in it.
    let photos: any PhotoStoring

    /// For failures with no caller to throw to (in-memory fallback, photo not written).
    private let errors: any ErrorReporting

    /// The store file, for measuring its size; zero-sized for in-memory runs.
    var storeURL: URL? { container.configurations.first?.url }

    /// Set when the on-disk store failed and the app runs from memory.
    private(set) var storageFailure: Error?

    /// One per store, so tests' in-memory stores never hear each other.
    let changes = DatabaseChangeFeed()

    /// Private so only `commit` can invalidate it and callers use the accessors.
    private var dailyPillsCache: [Date: [PillDose]] = [:]

    /// Shared by both initialisers so no model is registered in only one.
    private static func makeSchema() -> Schema {
        PlekioSchema.current()
    }

    // MARK: - Init

    init(photos: any PhotoStoring, errors: any ErrorReporting) {
        self.photos = photos
        self.errors = errors
        let schema = Self.makeSchema()

        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            // Migration plan, so older stores are upgraded instead of refused.
            container = try ModelContainer(for: schema, migrationPlan: PlekioMigrationPlan.self, configurations: [config])
        } catch {
            // Never crash on launch: fall back to memory and surface storageFailure.
            AppLog.storage.critical("Failed to open the on-disk store: \(error.localizedDescription, privacy: .public)")

            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let memoryContainer = try? ModelContainer(for: schema, configurations: [fallback]) else {
                fatalError("🚨 SwiftData is unavailable even in memory: \(error)")
            }

            container = memoryContainer
            storageFailure = error
        }

        context = container.mainContext

        if let failure = storageFailure {
            errors.report(DatabaseError.storageUnavailable(underlying: failure))
        }
    }

    /// An in-memory store for tests; always in-memory regardless of the flag.
    init(inMemory: Bool, photos: any PhotoStoring, errors: any ErrorReporting) {
        self.photos = photos
        self.errors = errors
        do {
            let schema = Self.makeSchema()
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, migrationPlan: PlekioMigrationPlan.self, configurations: [config])
            context = container.mainContext
        } catch {
            fatalError("Failed to initialize test (in-memory) SwiftData: \(error)")
        }
    }

    // MARK: - Commit

    /// The only place the context is saved. Never `try?`: on failure roll back and
    /// rethrow. `changes` has no default so every write declares what it touched.
    func commit(_ changes: Set<DatabaseChange>) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            dailyPillsCache.removeAll()
            throw DatabaseError.saveFailed(underlying: error)
        }

        // Invalidated here, not per call site, so no write can leave a stale dose.
        dailyPillsCache.removeAll()

        self.changes.send(changes)
    }

    // MARK: - Background Reads

    private var cachedReader: BackgroundReader?

    /// Created off the main thread: a `@ModelActor` made on the main thread runs its
    /// context on the main queue, which defeats the point.
    func backgroundReader() async -> BackgroundReader {
        if let cachedReader { return cachedReader }
        let container = self.container
        let reader = await Task.detached(priority: .userInitiated) {
            BackgroundReader(modelContainer: container)
        }.value
        cachedReader = reader
        return reader
    }

    // MARK: - Day Cache

    func cachedPills(for day: Date) -> [PillDose]? {
        dailyPillsCache[day]
    }

    func cachePills(_ pills: [PillDose], for day: Date) {
        dailyPillsCache[day] = pills
    }

    // MARK: - Read Failures

    /// Shows one alert per run of failed reads; cleared by the next successful read.
    private var readFailureReported = false

    /// Logs a failed read and tells the user, so a broken store isn't mistaken for an empty one.
    func reportReadFailure(_ error: Error) {
        AppLog.storage.error("Read failed: \(error.localizedDescription, privacy: .public)")
        guard !readFailureReported else { return }
        readFailureReported = true
        errors.report(DatabaseError.readFailed(underlying: error))
    }

    func readSucceeded() {
        readFailureReported = false
    }

    // MARK: - Photos

    /// Writes all photos or none: on any failure the ones already written are
    /// deleted and the save is refused, so a record never points at missing files.
    func writePhotosOrThrow(_ photos: [(UUID, Data)]) throws {
        var written: [UUID] = []
        for (id, data) in photos {
            guard self.photos.saveToDisk(data, for: id) else {
                for id in written { self.photos.deleteFromDisk(for: id) }
                AppLog.media.error("Photo not written; save refused")
                throw DatabaseError.saveFailed(underlying: PhotoWriteFailed())
            }
            written.append(id)
        }
    }

    /// Writes photos after their record is committed. Failures are reported, not
    /// thrown or rolled back: the record is already safely saved.
    func persistPhotos(_ photos: [(UUID, Data)]) {
        var failures = 0
        for (id, data) in photos where !self.photos.saveToDisk(data, for: id) {
            failures += 1
        }

        guard failures > 0 else { return }
        AppLog.media.error("Photos not written to disk: \(failures, privacy: .public)")
        errors.report(DatabaseError.photoNotSaved)
    }
}

// MARK: - DatabaseError

/// Storage failures with user-readable text instead of SwiftData's raw description.
enum DatabaseError: LocalizedError, AlertTitled {
    /// Running from memory; reported once at launch.
    case storageUnavailable(underlying: Error)

    case saveFailed(underlying: Error)

    /// The record was written but its photo was not. Reported, never thrown.
    case photoNotSaved

    /// A read failed and returned nothing. Reported, never thrown.
    case readFailed(underlying: Error)

    // MARK: - AlertTitled

    /// A failed read is not a failed save: the user shouldn't go looking for a lost edit.
    var alertTitle: LocalizedStringResource {
        if case .readFailed = self { return "Couldn't load your data" }
        return "Couldn't save"
    }

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .storageUnavailable:
            return String(localized: "Storage on this device is unavailable. The app is running in temporary mode — entries will not survive a restart.")
        case .saveFailed:
            return String(localized: "Couldn't save your changes. They were not written to the device.")
        case .readFailed:
            return String(localized: "Couldn't read your data from the device. What's on screen may be incomplete.")
        case .photoNotSaved:
            return String(localized: "Couldn't save a photo. Everything else was saved — the device may be out of storage.")
        }
    }

    var failureReason: String? {
        switch self {
        case .storageUnavailable:
            // The SwiftData detail goes to the log, not the user.
            return nil
        case .saveFailed(let underlying):
            return underlying.localizedDescription
        case .photoNotSaved, .readFailed:
            return nil
        }
    }
}

// MARK: - PhotoWriteFailed

/// A photo file could not be written, usually for lack of space.
nonisolated struct PhotoWriteFailed: Error {}

