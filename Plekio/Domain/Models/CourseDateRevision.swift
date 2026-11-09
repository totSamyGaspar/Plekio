import Foundation
import SwiftData

nonisolated extension SchemaV2 {

    /// The course dates in force before an edit. Past days keep their original
    /// bounds and frequency anchor; the current dates apply from the edit day.
    @Model
    nonisolated final class CourseDateRevision {
        var validUntil: Date = Date.distantPast
        var startDate: Date = Date.distantPast
        var endDate: Date = Date.distantPast
        var course: TreatmentCourse?

        init(validUntil: Date, startDate: Date, endDate: Date) {
            self.validUntil = validUntil
            self.startDate = startDate
            self.endDate = endDate
        }
    }
}
