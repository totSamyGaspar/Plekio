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
// V1 is frozen (git tag `schema-v1`): SchemaFreezeTests fails on any change to
// a V1 model and opens a store V1 wrote with the current schema. To change the schema:
// - Copy every model file into `extension SchemaV2 { … }` (all of them: models
//   reference each other through relationships) and edit only the V2 copies.
// - Add `SchemaV2: VersionedSchema`; point `Current` at it.
// - Append V2 to `PlekioMigrationPlan.schemas` and add a stage: `.lightweight`
//   for additive changes, `.custom` when data must be moved or rewritten.
// - Extend SchemaV1Fixture.expectMatches for what V2 changed; once V2 ships,
//   freeze it the same way (SchemaV2.manifest, SchemaV2.store).

// MARK: - Current

/// The single source of the current schema version for the app and tests.
nonisolated enum PlekioSchema {
    typealias Current = SchemaV1

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

// MARK: - Migration plan

nonisolated enum PlekioMigrationPlan: SchemaMigrationPlan {

    /// Every shipped version, oldest first. Never remove one: old stores exist.
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    /// Always `schemas.count - 1` stages, one per consecutive pair.
    static var stages: [MigrationStage] {
        []
    }
}
