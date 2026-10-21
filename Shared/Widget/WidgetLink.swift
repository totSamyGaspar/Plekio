//
//  WidgetLink.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - WidgetLink

/// Where a tap on a widget opens the app. Built by the widget (`widgetURL`), read
/// by the app (`onOpenURL`), so the URL's shape lives in one place.
nonisolated enum WidgetLink: Equatable, Sendable {

    /// The Today tab.
    case today

    /// The take-dose sheet for a slot's open doses, as a dose reminder's tap opens it.
    case dose(slot: Date, medicationIds: [UUID])

    /// Registered under CFBundleURLTypes in Plekio/Info.plist.
    static let scheme = "plekio"

    private enum Host {
        static let today = "today"
        static let dose = "dose"
    }

    private enum Query {
        static let slot = "slot"
        static let ids = "ids"
    }

    // MARK: - Building

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .today:
            components.host = Host.today
        case .dose(let slot, let ids):
            components.host = Host.dose
            components.queryItems = [
                // Seconds as Swift prints them: the shortest text that reads back exactly.
                URLQueryItem(name: Query.slot, value: String(slot.timeIntervalSince1970)),
                URLQueryItem(name: Query.ids, value: ids.map(\.uuidString).joined(separator: ","))
            ]
        }
        // Scheme and host are constants and the values are digits, dots, dashes and commas.
        return components.url ?? URL(fileURLWithPath: "/")
    }

    // MARK: - Reading

    /// Nil for another app's URL, an unknown host, or a dose link that names nothing.
    init?(url: URL) {
        guard url.scheme == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        switch components.host {
        case Host.today:
            self = .today

        case Host.dose:
            let items = components.queryItems ?? []
            func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

            guard let slotText = value(Query.slot), let interval = Double(slotText) else { return nil }
            let ids = (value(Query.ids) ?? "")
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
            guard !ids.isEmpty else { return nil }
            self = .dose(slot: Date(timeIntervalSince1970: interval), medicationIds: ids)

        default:
            return nil
        }
    }
}

// MARK: - Slot

extension WidgetSnapshot.Slot {

    /// The take-dose sheet for what is still open in the slot; Today once nothing is.
    var openLink: WidgetLink {
        let open = doses.filter { $0.status == .pending }.map(\.medicationId)
        return open.isEmpty ? .today : .dose(slot: time, medicationIds: open)
    }
}
