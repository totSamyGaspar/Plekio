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

    static let shared = DatabaseService()

    let persistence: PersistenceController

    var container: ModelContainer { persistence.container }
    var context: ModelContext { persistence.context }

    /// Set when the on-disk store could not be opened and the app is running from
    /// memory. Nothing survives a restart in that mode.
    var storageFailure: Error? { persistence.storageFailure }

    private init() {
        persistence = PersistenceController()
    }

    /// Test-only entry point. `shared` is disk-backed, so tests using it would
    /// collide with real app data and with each other. This builds an independent
    /// in-memory container on the same schema, exercising the real logic without
    /// touching disk.
    init(inMemoryForTesting: Bool) {
        persistence = PersistenceController(inMemory: inMemoryForTesting)
    }
}

/// The whole surface, assembled from the four conformances in the extension
/// files. Declared here and satisfied entirely by them — this type adds no
/// storage operations of its own.
extension DatabaseService: DatabaseServiceProtocol {}
