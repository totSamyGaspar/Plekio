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

    var container: ModelContainer { persistence.container }
    var context: ModelContext { persistence.context }

    /// Set when the on-disk store could not be opened and the app is running from
    /// memory. Nothing survives a restart in that mode.
    var storageFailure: Error? { persistence.storageFailure }

    /// Photo files, kept beside the store — see PersistenceController.
    var photos: any PhotoStoring { persistence.photos }

    /// The on-disk store. Built once, by the composition root
    /// (`AppDependencies.live()`); there is no `shared` to reach for.
    init(photos: any PhotoStoring, errors: any ErrorReporting) {
        persistence = PersistenceController(photos: photos, errors: errors)
    }

    /// Test-only entry point: an independent in-memory container on the same
    /// schema, exercising the real logic without touching the on-disk store.
    init(inMemoryForTesting: Bool, photos: any PhotoStoring, errors: any ErrorReporting) {
        persistence = PersistenceController(inMemory: inMemoryForTesting, photos: photos, errors: errors)
    }

    /// The shape existing tests use. Photos still go to the shared cache and
    /// errors to a presenter nobody shows; pass both explicitly to isolate them.
    convenience init(inMemoryForTesting: Bool) {
        self.init(inMemoryForTesting: inMemoryForTesting, photos: ImageCache.shared, errors: AppErrorPresenter())
    }
}

/// The whole surface, assembled from the four conformances in the extension
/// files. Declared here and satisfied entirely by them — this type adds no
/// storage operations of its own.
extension DatabaseService: DatabaseServiceProtocol {}
