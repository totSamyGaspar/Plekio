//
//  PersistenceReportingTests.swift
//  PlekioTests
//
//  The storage layer now reaches the outside world only through two
//  abstractions — PhotoStoring and ErrorReporting — so both can be swapped for
//  fakes. Before, it wrote into the app's real photo folder and set the text of
//  the app's one alert directly.
//

import Testing
import Foundation
@testable import Plekio

/// Remembers what it was asked to store, and can be told to refuse.
nonisolated final class FakePhotoStore: PhotoStoring, @unchecked Sendable {
    private(set) var saved: [UUID: Data] = [:]
    private(set) var deleted: [UUID] = []
    let refusesWrites: Bool

    init(refusesWrites: Bool = false) {
        self.refusesWrites = refusesWrites
    }

    func saveToDisk(_ data: Data, for id: UUID) -> Bool {
        guard !refusesWrites else { return false }
        saved[id] = data
        return true
    }

    func loadDataFromDisk(for id: UUID) -> Data? { saved[id] }

    func deleteFromDisk(for id: UUID) {
        saved[id] = nil
        deleted.append(id)
    }
}

@MainActor
@Suite("Persistence reporting")
struct PersistenceReportingTests {

    @Test("фото, не записанное на диск, уходит в ErrorReporting, а не в синглтон")
    func unsavedPhotoIsReported() {
        let errors = SpyErrorReporter()
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(refusesWrites: true), errors: errors)

        db.persistence.persistPhotos([(UUID(), Data([0xFF, 0xD8]))])

        #expect(errors.reported.count == 1)
        guard case .photoNotSaved = errors.reported.first as? DatabaseError else {
            Issue.record("expected DatabaseError.photoNotSaved, got \(String(describing: errors.reported.first))")
            return
        }
    }

    @Test("успешная запись фото ничего не сообщает и пишет в переданное хранилище")
    func savedPhotoGoesToTheInjectedStore() {
        let errors = SpyErrorReporter()
        let photos = FakePhotoStore()
        let db = DatabaseService(inMemoryForTesting: true, photos: photos, errors: errors)
        let id = UUID()

        db.persistence.persistPhotos([(id, Data([0x01]))])

        #expect(errors.reported.isEmpty)
        #expect(photos.saved[id] == Data([0x01]))
    }
}
