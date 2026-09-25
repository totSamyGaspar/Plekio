//
//  DatabaseService.swift
//  Plekio
//

import Foundation
import OSLog
import SwiftData

/// The app's storage, as one object.
///
/// Almost nothing lives here. The machinery is `PersistenceController`; the
/// operations are in four extensions, one per part of the domain —
/// `+Courses`, `+Doses`, `+Diary`, `+BloodPressure` — each conforming to its own
/// narrow protocol.
///
/// This type exists so there is still one thing to register and one thing to
/// pass around. Callers should NOT ask for it: they take the protocol they
/// actually use, so the dashboard cannot reach the diary and the diary cannot
/// reach the dose log.
@MainActor
final class DatabaseService {

    let persistence: PersistenceController

    /// When a dose was logged or skipped — see TimeSource.
    let time: any TimeSource

    var container: ModelContainer { persistence.container }
    var context: ModelContext { persistence.context }

    /// Set when the on-disk store could not be opened and the app is running from
    /// memory. Nothing survives a restart in that mode.
    var storageFailure: Error? { persistence.storageFailure }

    /// Photo files, kept beside the store — see PersistenceController.
    var photos: any PhotoStoring { persistence.photos }

    /// This store's writes — see DatabaseChangeFeed.
    var changes: DatabaseChangeFeed { persistence.changes }

    /// The on-disk store. Built once, by the composition root
    /// (`AppDependencies.live()`); there is no `shared` to reach for.
    init(photos: any PhotoStoring, errors: any ErrorReporting, time: any TimeSource = SystemTime()) {
        persistence = PersistenceController(photos: photos, errors: errors)
        self.time = time
    }

    /// Test-only entry point: an independent in-memory container on the same
    /// schema, exercising the real logic without touching the on-disk store.
    init(inMemoryForTesting: Bool, photos: any PhotoStoring, errors: any ErrorReporting, time: any TimeSource = SystemTime()) {
        persistence = PersistenceController(inMemory: inMemoryForTesting, photos: photos, errors: errors)
        self.time = time
    }

    /// The shape most tests use: an in-memory store with a photo folder of its
    /// own in the temporary directory, so no test reads or writes the app's real
    /// photos. Errors go to a presenter nobody shows.
    convenience init(inMemoryForTesting: Bool) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlekioTestPhotos-\(UUID().uuidString)", isDirectory: true)
        self.init(inMemoryForTesting: inMemoryForTesting, photos: ImageCache(directory: folder), errors: AppErrorPresenter())
    }
}

// MARK: - Reading

extension DatabaseService {

    /// The one place the store is read. A failure is reported through the
    /// persistence controller instead of vanishing into `try?` — see
    /// `PersistenceController.reportReadFailure`.
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

/// The whole surface, assembled from the four conformances in the extension
/// files. Declared here and satisfied entirely by them — this type adds no
/// storage operations of its own.
extension DatabaseService: DatabaseServiceProtocol {}
