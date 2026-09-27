import Foundation
import SwiftData

/// The course dates in force before an edit. Past days keep their original
/// bounds and frequency anchor; the current dates apply from the edit day.
@Model
nonisolated final class CourseDateRevision {
    var validUntil: Date
    var startDate: Date
    var endDate: Date
    var course: TreatmentCourse?

    init(validUntil: Date, startDate: Date, endDate: Date) {
        self.validUntil = validUntil
        self.startDate = startDate
        self.endDate = endDate
    }
}
