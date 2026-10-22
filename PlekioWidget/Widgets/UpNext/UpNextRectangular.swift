//
//  UpNextRectangular.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Lock Screen

/// Half a Lock Screen row: no room for a title, so the header is the time and what
/// it is for, and the medication goes underneath.
struct UpNextRectangular: View {
    let entry: DoseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            switch UpNext(entry) {
            case .next(let slot):
                header {
                    slot.time.widgetTime
                    Text(verbatim: "·")
                    Text(slot.period.title)
                }
                names(slot.doses)
            case .missed(let slot):
                header {
                    Text("MISSED")
                    Text(verbatim: "·")
                    slot.time.widgetTime
                }
                names(slot.doses.filter { $0.status == .pending })
            case .complete:
                header { Text("Today") }
                Text("Day complete")
                    .font(.widgetSerif(16))
                    .lineLimit(1)
                if let days = entry.snapshot?.streakDays, days > 0 {
                    Text("\(days) days streak!")
                        .font(.caption)
                        .lineLimit(1)
                }
            case .empty(let tomorrow):
                header { Text("Today") }
                Text("Nothing for today")
                    .font(.widgetSerif(15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let tomorrow {
                    HStack(spacing: 4) {
                        Text("Tomorrow")
                        tomorrow.time.widgetTime
                    }
                    .font(.caption)
                }
            case .needsApp:
                header { EmptyView() }
                Text("Open Plekio to update")
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func header<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) {
            WidgetLogo(size: 12)
            content()
        }
        .font(.caption.weight(.heavy))
        .textCase(.uppercase)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .widgetAccentable()
    }

    private func names(_ doses: [WidgetSnapshot.Dose]) -> some View {
        Group {
            Text(doses.first?.name ?? "")
                .font(.widgetSerif(16))
                .lineLimit(1)
            if doses.count > 1 {
                Text("\(doses.count - 1) more")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
    }
}
