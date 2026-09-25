//
//  PlekioSchemaTests.swift
//  PlekioTests
//
//  Created by Edward Gasparian on 25.09.2026.
//

import Testing
import Foundation
import SwiftData
@testable import Plekio

@MainActor
@Suite("Schema and migration plan")
struct PlekioSchemaTests {

    // MARK: - Migration plan

    @Test("план согласован: версии по возрастанию, один шаг между соседними, последняя — текущая")
    func planIsConsistent() {
        let schemas = PlekioMigrationPlan.schemas
        let versions = schemas.map { $0.versionIdentifier }

        #expect(!schemas.isEmpty)
        #expect(zip(versions, versions.dropFirst()).allSatisfy { $0 < $1 })
        #expect(PlekioMigrationPlan.stages.count == schemas.count - 1)
        #expect(ObjectIdentifier(schemas.last!) == ObjectIdentifier(PlekioSchema.Current.self))
    }

    @Test("текущая схема содержит все модели хранилища")
    func currentSchemaHasEveryModel() {
        let names = Set(PlekioSchema.current().entities.map(\.name))

        #expect(names == ["TreatmentCourse", "MedicationItem", "DoseLog", "DiaryEntry", "BloodPressureReading"])
    }

    // MARK: - Store on disk

    @Test("хранилище на диске открывается заново через план миграций и сохраняет данные")
    func storeOnDiskReopensThroughThePlan() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlekioSchemaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("store.sqlite")
        let schema = PlekioSchema.current()

        func open() throws -> ModelContainer {
            try ModelContainer(
                for: schema,
                migrationPlan: PlekioMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: url)]
            )
        }

        do {
            let container = try open()
            let course = TreatmentCourse(name: "Курс", startDate: Date(), endDate: Date().addingTimeInterval(86400))
            container.mainContext.insert(course)
            try container.mainContext.save()
        }

        let reopened = try open()
        let courses = try reopened.mainContext.fetch(FetchDescriptor<TreatmentCourse>())
        #expect(courses.map(\.name) == ["Курс"])
    }
}
