//
//  PlekioSchema.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Foundation
import SwiftData

// Changing the schema (once V1 has shipped, it is frozen):
// - Copy the shipped models into `extension SchemaV1 { … }` unchanged.
// - Add `SchemaV2: VersionedSchema` with the new models; point `Current` at it.
// - Append V2 to `PlekioMigrationPlan.schemas` and add a stage: `.lightweight`
//   for additive changes, `.custom` when data must be moved or rewritten.
// - Extend PlekioSchemaTests: a store written in V1, opened in V2.
// Before the first release, edit models freely and reinstall.

// MARK: - Current

/// The single source of the current schema version for the app and tests.
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

    /// Every shipped version, oldest first. Never remove one: old stores exist.
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    /// Always `schemas.count - 1` stages, one per consecutive pair.
    static var stages: [MigrationStage] {
        []
    }
}
