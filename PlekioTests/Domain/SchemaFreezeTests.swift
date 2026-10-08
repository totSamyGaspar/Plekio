//
//  SchemaFreezeTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 08.10.2026.
//

import Testing
import Foundation
import SwiftData
import SQLite3
@testable import Plekio

// V1 shipped, so its shape is frozen. Two files in Fixtures/ hold it:
// - SchemaV1.manifest: every entity, attribute and relationship, as text. A
//   change to a V1 model fails `v1ShapeIsFrozen`; the change belongs in V2.
// - SchemaV1.store: a store written by V1 with SchemaV1Fixture's data. Every
//   later version must open it through the migration plan with nothing lost.
//
// Both are written once, by the shipped code, and never regenerated:
//   TEST_RUNNER_PLEKIO_FIXTURE_OUTPUT="$PWD/PlekioTests/Fixtures" xcodebuild test \
//     -scheme Plekio -destination '…' -only-testing:PlekioTests/SchemaFreezeTests/writeV1Fixtures

@MainActor
@Suite("Schema freeze")
struct SchemaFreezeTests {

    // MARK: - Shape

    @Test("SchemaV1 has the shape it shipped with")
    func v1ShapeIsFrozen() throws {
        let frozen = try String(contentsOf: Fixtures.url("SchemaV1", "manifest"), encoding: .utf8)

        #expect(
            SchemaManifest.of(SchemaV1.self) == frozen,
            "SchemaV1 changed after it shipped. Put the change in a new SchemaV2 (see PlekioSchema.swift)."
        )
    }

    // MARK: - Migration

    @Test("The V1 store opens with the current schema and keeps every value")
    func v1StoreOpensWithTheCurrentSchema() throws {
        let directory = try Fixtures.scratchDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        // A copy: opening migrates in place, and the bundled file must stay V1.
        let store = directory.appending(path: "Plekio.store")
        try FileManager.default.copyItem(at: Fixtures.url("SchemaV1", "store"), to: store)

        let schema = PlekioSchema.current()
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PlekioMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: store)]
        )

        try SchemaV1Fixture.expectMatches(container.mainContext)
    }

    // MARK: - Writing the fixtures

    @Test(
        "Writes the V1 fixtures (only when asked)",
        .enabled(if: Fixtures.outputDirectory != nil, "Set TEST_RUNNER_PLEKIO_FIXTURE_OUTPUT to write the fixtures")
    )
    func writeV1Fixtures() throws {
        let output = try #require(Fixtures.outputDirectory)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let store = output.appending(path: "SchemaV1.store")
        try #require(!FileManager.default.fileExists(atPath: store.path), "The V1 fixture exists already; it is never rewritten.")

        let schema = Schema(versionedSchema: SchemaV1.self)
        do {
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: store)])
            SchemaV1Fixture.populate(container.mainContext)
            try container.mainContext.save()
            try SchemaV1Fixture.expectMatches(container.mainContext)
        }
        try Fixtures.collapseIntoOneFile(store)

        try SchemaManifest.of(SchemaV1.self)
            .write(to: output.appending(path: "SchemaV1.manifest"), atomically: true, encoding: .utf8)
    }
}

// MARK: - SchemaManifest

/// A schema as sorted plain text: what the store's shape depends on, nothing else.
@MainActor
enum SchemaManifest {

    static func of(_ version: any VersionedSchema.Type) -> String {
        let schema = Schema(versionedSchema: version)
        var lines = ["version \(version.versionIdentifier)"]

        for entity in schema.entities.sorted(by: { $0.name < $1.name }) {
            lines.append("entity \(entity.name)")

            let attributes = entity.attributes.map { attribute in
                // valueType already reads Optional<…> for an optional attribute.
                "  attribute \(attribute.name): \(attribute.valueType)"
                    + (attribute.isUnique ? " unique" : "")
            }
            let relationships = entity.relationships.map { relationship in
                "  relationship \(relationship.name): "
                    + (relationship.isToOneRelationship ? relationship.destination : "[\(relationship.destination)]")
                    + " inverse \(relationship.inverseName ?? "-")"
                    + " delete \(relationship.deleteRule)"
            }
            lines += (attributes + relationships).sorted()
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - Fixtures

@MainActor
private enum Fixtures {

    private final class BundleToken {}

    /// Where `writeV1Fixtures` writes; nil in a normal run.
    nonisolated static var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["PLEKIO_FIXTURE_OUTPUT"].map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    static func url(_ name: String, _ ext: String) throws -> URL {
        try #require(
            Bundle(for: BundleToken.self).url(forResource: name, withExtension: ext),
            "\(name).\(ext) is missing from the test bundle; it lives in PlekioTests/Fixtures."
        )
    }

    static func scratchDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "SchemaFreezeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Folds the WAL into the main file and switches journaling off WAL, so the
    /// fixture is one self-contained file; SwiftData turns WAL back on when it opens it.
    static func collapseIntoOneFile(_ store: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(store.path, &db) == SQLITE_OK else { throw FixtureError(store) }
        let folded = sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE;", nil, nil, nil)
        sqlite3_close(db)
        guard folded == SQLITE_OK else { throw FixtureError(store) }

        // The WAL would hold data; it must be gone. The -shm is only an index and may linger.
        let (wal, shm) = (URL(filePath: store.path + "-wal"), URL(filePath: store.path + "-shm"))
        guard !FileManager.default.fileExists(atPath: wal.path) else { throw FixtureError(store) }
        try? FileManager.default.removeItem(at: shm)
    }

    struct FixtureError: Error, CustomStringConvertible {
        let store: URL
        init(_ store: URL) { self.store = store }
        var description: String { "Couldn't collapse \(store.lastPathComponent) into one file" }
    }
}
