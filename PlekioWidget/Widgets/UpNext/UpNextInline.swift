//
//  UpNextInline.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

struct UpNextInline: View {
    let entry: DoseEntry

    var body: some View {
        // One line of system-styled text; images other than SF Symbols are dropped here.
        switch UpNext(entry) {
        case .next(let slot), .missed(let slot):
            Label {
                // Concatenated, not interpolated: the name and time aren't text to translate.
                slot.time.widgetTime + Text(verbatim: " · \(slot.doses.first?.name ?? "")")
            } icon: {
                Image(systemName: "pills.fill")
            }
        case .complete:
            Label("Day complete", systemImage: "checkmark.seal.fill")
        case .empty:
            Text("Nothing for today")
        case .needsApp:
            Text("Open Plekio to update")
        }
    }
}
