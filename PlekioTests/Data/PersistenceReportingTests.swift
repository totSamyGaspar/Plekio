//
//  PersistenceReportingTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
@testable import Plekio

@MainActor
@Suite("Persistence reporting")
struct PersistenceReportingTests {

    // MARK: - Photos

    @Test("A photo that failed to write goes to ErrorReporting, not a singleton")
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

    @Test("A successful photo write reports nothing and writes to the injected store")
    func savedPhotoGoesToTheInjectedStore() {
        let errors = SpyErrorReporter()
        let photos = FakePhotoStore()
        let db = DatabaseService(inMemoryForTesting: true, photos: photos, errors: errors)
        let id = UUID()

        db.persistence.persistPhotos([(id, Data([0x01]))])

        #expect(errors.reported.isEmpty)
        #expect(photos.saved[id] == Data([0x01]))
    }

    // MARK: - Read failures

    @Test("A read failure is reported once per run, and again after a successful read")
    func readFailureIsReportedOncePerStreak() {
        let errors = SpyErrorReporter()
        let db = DatabaseService(inMemoryForTesting: true, photos: FakePhotoStore(), errors: errors)
        let failure = NSError(domain: "test", code: 1)

        db.persistence.reportReadFailure(failure)
        db.persistence.reportReadFailure(failure)
        #expect(errors.reported.count == 1)
        guard case .readFailed = errors.reported.first as? DatabaseError else {
            Issue.record("expected DatabaseError.readFailed, got \(String(describing: errors.reported.first))")
            return
        }

        db.persistence.readSucceeded()
        db.persistence.reportReadFailure(failure)
        #expect(errors.reported.count == 2)
    }

    // MARK: - Presenter

    @Test("A read-failure alert isn't titled Couldn't save")
    func presenterTitleFollowsTheKindOfFailure() {
        let presenter = AppErrorPresenter()

        presenter.report(DatabaseError.readFailed(underlying: NSError(domain: "test", code: 1)))
        #expect(presenter.title.key == "Couldn't load your data")
        #expect(presenter.message != nil)

        presenter.report(DatabaseError.saveFailed(underlying: NSError(domain: "test", code: 2)))
        #expect(presenter.title.key == "Couldn't save")
    }
}
