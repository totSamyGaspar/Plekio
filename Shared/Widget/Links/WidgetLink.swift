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

    /// The diary check-in form, as the daily diary reminder opens it.
    case diaryCheckIn

    /// The blood-pressure entry form, as the daily blood-pressure reminder opens it.
    case bloodPressureEntry

    /// Registered under CFBundleURLTypes in Plekio/Info.plist.
    static let scheme = "plekio"

    private enum Host {
        static let today = "today"
        static let dose = "dose"
        static let diary = "diary"
        static let bloodPressure = "blood-pressure"
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
        case .diaryCheckIn:
            components.host = Host.diary
        case .bloodPressureEntry:
            components.host = Host.bloodPressure
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

        case Host.diary:
            self = .diaryCheckIn

        case Host.bloodPressure:
            self = .bloodPressureEntry

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
