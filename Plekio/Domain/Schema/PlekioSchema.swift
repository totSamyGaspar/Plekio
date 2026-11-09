//
//  PlekioSchema.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import SwiftData

// Each version owns its models: they are declared inside `extension SchemaVn { … }`,
// so an edit for V2 can never silently change V1 (both would then share one
// checksum and the migration would fail). The app uses the typealiases below.
//
// V1 and V2 are frozen (git tags `schema-v1`, `schema-v2`): SchemaFreezeTests fails on
// any change to their models and opens a store each wrote with the current schema.
// To change the schema:
// - Move V2's model files to `V2/` as frozen copies, then declare the current models
//   in `extension SchemaV3 { … }` (all of them: models reference each other through
//   relationships) and edit only those.
// - Add `SchemaV3: VersionedSchema`; point `Current` at it.
// - Append V3 to `PlekioMigrationPlan.schemas` and add a stage: `.lightweight`
//   for additive changes, `.custom` when data must be moved or rewritten.
// - Extend SchemaV1Fixture and SchemaV2Fixture `expectMatches` for what V3 changed;
//   once V3 ships, freeze it the same way (SchemaV3.manifest, SchemaV3.store).

// MARK: - Current

/// The single source of the current schema version for the app and tests.
nonisolated enum PlekioSchema {
    typealias Current = SchemaV2

    static func current() -> Schema {
        Schema(versionedSchema: Current.self)
    }
}

// MARK: - Model Names

// The rest of the app names models without a version; these follow `Current`.
typealias TreatmentCourse = PlekioSchema.Current.TreatmentCourse
typealias CourseDateRevision = PlekioSchema.Current.CourseDateRevision
typealias MedicationItem = PlekioSchema.Current.MedicationItem
typealias DoseLog = PlekioSchema.Current.DoseLog
typealias ScheduleRevision = PlekioSchema.Current.ScheduleRevision
typealias DiaryEntry = PlekioSchema.Current.DiaryEntry
typealias BloodPressureReading = PlekioSchema.Current.BloodPressureReading

// MARK: - Versions

nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TreatmentCourse.self,
            CourseDateRevision.self,
            MedicationItem.self,
            DoseLog.self,
            ScheduleRevision.self,
            DiaryEntry.self,
            BloodPressureReading.self,
        ]
    }
}

/// Adds MedicationItem.mealTiming; keeps course days, revisions and dose slots as local
/// days and times (LocalDay, LocalSlot); and is CloudKit-ready: no unique attributes, a
/// default or nil for every attribute, optional relationships. Frozen: see SchemaFreezeTests.
nonisolated enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TreatmentCourse.self,
            CourseDateRevision.self,
            MedicationItem.self,
            DoseLog.self,
            ScheduleRevision.self,
            DiaryEntry.self,
            BloodPressureReading.self,
        ]
    }
}

// MARK: - Migration plan

nonisolated enum PlekioMigrationPlan: SchemaMigrationPlan {

    /// Every shipped version, oldest first. Never remove one: old stores exist.
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    /// Always `schemas.count - 1` stages, one per consecutive pair.
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// The structure moves as in a lightweight migration (attributes added, relaxed and
    /// renamed with `originalName`); then days and slots become local, see LocalTimeMigration.
    static var migrateV1toV2: MigrationStage {
        .custom(fromVersion: SchemaV1.self, toVersion: SchemaV2.self, willMigrate: nil) { context in
            try LocalTimeMigration.run(in: context, calendar: .autoupdatingCurrent)
        }
    }
}
