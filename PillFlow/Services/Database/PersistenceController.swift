//
//  PersistenceController.swift
//  PillFlow
//

import Foundation
import OSLog
import SwiftData

/// The storage machinery: the container, the context, and the one place a write
/// is committed.
///
/// Split out of DatabaseService because it is a different kind of thing from the
/// domain operations around it. It owns three invariants that have nothing to do
/// with courses or diaries and everything to do with not losing data — a failed
/// save rolls back and rethrows, every successful write invalidates the day cache,
/// and every write announces what it touched — and those are easier to keep right
/// when they are not spread through six hundred lines of domain code.
@MainActor
final class PersistenceController {

    let container: ModelContainer
    let context: ModelContext

    /// Where the store file sits, for measuring it. In-memory runs still name a
    /// path; nothing is written there, so the measurement comes out zero.
    var storeURL: URL? { container.configurations.first?.url }

    /// Set when the on-disk store could not be opened and the app fell back to an
    /// in-memory container. Nothing survives a restart in that mode, so the UI has
    /// to tell the user.
    private(set) var storageFailure: Error?

    /// Today's doses, and any other day the user has scrolled to in this session.
    ///
    /// Private, and reached through the two accessors below: it is cleared by
    /// `commit`, and a dictionary that any caller could write to directly would
    /// make that guarantee unenforceable.
    private var dailyPillsCache: [Date: [PillDose]] = [:]

    /// Single source of truth for the schema: both initialisers read it, so a model
    /// cannot end up registered in only one of them.
    private static func makeSchema() -> Schema {
        Schema([
            TreatmentCourse.self, MedicationItem.self, DoseLog.self, DiaryEntry.self,
            BloodPressureReading.self,
        ])
    }

    // MARK: - Init

    init() {
        let schema = Self.makeSchema()

        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Crashing on launch is the worst outcome: the user just sees the app die
            // with no idea what happened to their history. Fall back to memory and
            // surface storageFailure instead.
            AppLog.storage.critical("Failed to open the on-disk store: \(error.localizedDescription, privacy: .public)")

            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let memoryContainer = try? ModelContainer(for: schema, configurations: [fallback]) else {
                // Not even memory works — there is nothing left to fall back to.
                fatalError("🚨 SwiftData is unavailable even in memory: \(error)")
            }

            container = memoryContainer
            storageFailure = error
        }

        context = container.mainContext

        if storageFailure != nil {
            AppErrorPresenter.shared.message = String(
                localized: "Storage on this device is unavailable. The app is running in temporary mode — entries will not survive a restart."
            )
        }
    }

    /// An independent in-memory store on the same schema, for tests.
    ///
    /// The flag is the caller's declaration of intent rather than a switch — this
    /// initialiser is always in-memory, and `init()` is the disk-backed one. It
    /// reads as `PersistenceController(inMemory: true)` at the only call site,
    /// which is `DatabaseService(inMemoryForTesting:)`.
    init(inMemory: Bool) {
        do {
            let schema = Self.makeSchema()
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: [config])
            context = container.mainContext
        } catch {
            fatalError("🚨 Failed to initialize test (in-memory) SwiftData: \(error)")
        }
    }

    // MARK: - Commit

    /// The only place the context is saved.
    ///
    /// Never `try?`: a swallowed failure reports "saved" for a write that never
    /// reached disk, which in a medication history is silent data loss. On failure
    /// the context is rolled back — memory never holds state that isn't on disk —
    /// and the error is rethrown.
    ///
    /// `changes` has no default on purpose. Every mutation has to say what it
    /// touched, and a new one cannot quietly inherit somebody else's answer.
    func commit(_ changes: Set<DatabaseChange>) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            dailyPillsCache.removeAll()
            throw DatabaseError.saveFailed(underlying: error)
        }

        // Invalidated here rather than in each mutating method: every write goes
        // through this function and every write invalidates the cache, so the two
        // belong together. Spread across call sites, one forgotten is a stale dose
        // on screen.
        dailyPillsCache.removeAll()

        NotificationCenter.default.post(
            name: .databaseDidChange,
            object: nil,
            userInfo: [DatabaseChange.userInfoKey: changes]
        )
    }

    // MARK: - Day cache

    func cachedPills(for day: Date) -> [PillDose]? {
        dailyPillsCache[day]
    }

    func cachePills(_ pills: [PillDose], for day: Date) {
        dailyPillsCache[day] = pills
    }


    /// Writes photos to disk after their record has been committed, and tells the
    /// user if any of them did not make it.
    ///
    /// The flag from `saveToDisk` was discarded at six call sites, so a record
    /// could be listed as saved while its photo had quietly vanished.
    ///
    /// It is reported rather than thrown, and rather than rolled back, because
    /// both of those are worse. The record is already committed; undoing a whole
    /// course because a thumbnail would not write is the wrong trade, and throwing
    /// here would run through `AppErrorPresenter.run`, which means telling the
    /// user nothing was saved and leaving the form open over data that is safely
    /// on disk. A retry queue does not fit either: the usual cause is a full
    /// device, and the bytes exist only in memory, so parking them for later needs
    /// the very disk that just refused. So the record stands and the user is told
    /// precisely which part of it is missing.
    func persistPhotos(_ photos: [(UUID, Data)]) {
        var failures = 0
        for (id, data) in photos where !ImageCache.shared.saveToDisk(data, for: id) {
            failures += 1
        }

        guard failures > 0 else { return }
        AppLog.media.error("Photos not written to disk: \(failures, privacy: .public)")
        AppErrorPresenter.shared.report(DatabaseError.photoNotSaved)
    }
}

/// A storage write failure. A dedicated type so the UI can show readable text
/// instead of SwiftData's raw description.
enum DatabaseError: LocalizedError {
    case saveFailed(underlying: Error)

    /// The record was written but its photo was not. Never thrown — see
    /// `PersistenceController.persistPhotos` for why this one is reported instead.
    case photoNotSaved

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return String(localized: "Couldn't save your changes. They were not written to the device.")
        case .photoNotSaved:
            return String(localized: "Couldn't save a photo. Everything else was saved — the device may be out of storage.")
        }
    }

    var failureReason: String? {
        switch self {
        case .saveFailed(let underlying):
            return underlying.localizedDescription
        case .photoNotSaved:
            return nil
        }
    }
}
