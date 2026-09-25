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

    // MARK: - Read failures

    @Test("сбой чтения сообщается один раз на серию и снова — после успешного чтения")
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

    @Test("алерт о сбое чтения не называется «Couldn't save»")
    func presenterTitleFollowsTheKindOfFailure() {
        let presenter = AppErrorPresenter()

        presenter.report(DatabaseError.readFailed(underlying: NSError(domain: "test", code: 1)))
        #expect(presenter.title.key == "Couldn't load your data")
        #expect(presenter.message != nil)

        presenter.report(DatabaseError.saveFailed(underlying: NSError(domain: "test", code: 2)))
        #expect(presenter.title.key == "Couldn't save")
    }
}
