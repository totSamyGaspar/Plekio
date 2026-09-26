//
//  FeatureTips.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI
import TipKit

// MARK: - Diary

struct CompareProgressTip: Tip {
    var title: Text { Text("Compare progress photos") }
    var message: Text? { Text("Add photos to your entries, then tick two in the gallery to see them side by side.") }
    var image: Image? { Image(systemName: "photo.on.rectangle.angled") }
    var rules: [Rule] { #Rule(PlekioTips.$tourFinished) { $0 } }
}

// MARK: - Courses

struct RepeatCourseTip: Tip {
    var title: Text { Text("Finished courses live in History") }
    var message: Text? { Text("Open History and tap Repeat to start the same treatment again with new dates.") }
    var image: Image? { Image(systemName: "arrow.clockwise") }
    var rules: [Rule] { #Rule(PlekioTips.$tourFinished) { $0 } }
}

// MARK: - Settings

struct DoctorReportTip: Tip {
    var title: Text { Text("A report for your doctor") }
    var message: Text? { Text("Build a PDF with doses, well-being and blood pressure for any period.") }
    var image: Image? { Image(systemName: "doc.richtext") }
    var rules: [Rule] { #Rule(PlekioTips.$tourFinished) { $0 } }
}

// MARK: - Today

struct DoseCheckmarkTip: Tip {
    var title: Text { Text("Tap the circle to change a dose") }
    var message: Text? { Text("Logged by mistake? Tap the check to undo it. Skipped or missed a dose? Tap the circle to log it.") }
    var image: Image? { Image(systemName: "checkmark.circle") }
    var rules: [Rule] { #Rule(PlekioTips.$tourFinished) { $0 } }
}
