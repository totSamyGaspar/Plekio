//
//  PlekioSchema.swift
//  Plekio
//
//  The store's schema, versioned, and the plan for moving a store from any
//  shipped version to the current one.
//
//  Until now the schema was an unversioned list of models, and every change so
//  far added an optional field — the one kind of change SwiftData migrates on
//  its own. The first rename, type change or data move would have left the
//  store unopenable: the app falls back to memory and a medication history
//  silently stops being saved. With a plan in place, such a change is a
//  migration stage written and tested before it ships.
//
//  HOW TO CHANGE THE SCHEMA
//
//  Before the first release: edit the models freely and reinstall the app.
//  SchemaV1 is not frozen yet — nothing on a user's device depends on it.
//
//  After a release, SchemaV1 is frozen for good. For a change:
//    1. Copy the current model definitions into `extension SchemaV1 { … }`,
//       exactly as they shipped, so V1 keeps describing what is on devices.
//    2. Add `enum SchemaV2: VersionedSchema` with the new models, and point
//       `PlekioSchema.current` at it.
//    3. Append SchemaV2 to `PlekioMigrationPlan.schemas` and a stage to
//       `stages` — `.lightweight` for additive changes, `.custom` when data has
//       to be moved or rewritten.
//    4. Extend PlekioSchemaTests with a store written in V1 and opened in V2.
//

import Foundation
import SwiftData

/// The current version, as the store opens it. The one place that says which
/// schema is "now" — PersistenceController and the tests read it from here.
nonisolated enum PlekioSchema {
    typealias Current = SchemaV1

    static func current() -> Schema {
        Schema(versionedSchema: Current.self)
    }
}

// MARK: - Versions

nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TreatmentCourse.self,
            MedicationItem.self,
            DoseLog.self,
            DiaryEntry.self,
            BloodPressureReading.self,
        ]
    }
}

// MARK: - Migration plan

nonisolated enum PlekioMigrationPlan: SchemaMigrationPlan {

    /// Every version that has ever shipped, oldest first. A version is never
    /// removed: a user who skipped updates still has a store in it.
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    /// One stage per step between consecutive versions — always
    /// `schemas.count - 1` of them.
    static var stages: [MigrationStage] {
        []
    }
}
