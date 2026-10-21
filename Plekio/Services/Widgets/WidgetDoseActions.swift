//
//  WidgetDoseActions.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.10.2026.
//

import Foundation

// MARK: - WidgetDoseActions

/// Carries out a widget button in the app. Hands it to NotificationResponseHandler,
/// as a notification's Take or Skip would be: same rules, same reminder rebuild.
@MainActor
enum WidgetDoseActions {

    static func take(_ ids: [UUID], at slot: Date) async {
        await run(.take(medicationIds: ids, slot: slot))
    }

    static func skip(_ ids: [UUID], at slot: Date) async {
        await run(.skip(medicationIds: ids, slot: slot))
    }

    /// The snapshot is rewritten right after the write, before the reminder rebuild:
    /// WidgetKit dims the widget until `perform()` returns, then redraws from the snapshot.
    private static func run(_ intent: NotificationIntent) async {
        guard !intentIsEmpty(intent), let delegate = AppDelegate.shared else { return }

        // Reading `launcher` opens the store if this launch came from the widget.
        guard let dependencies = delegate.launcher.dependencies else {
            await AppDelegate.reportNotRecorded()
            return
        }
        await dependencies.notificationResponses.handle(intent) {
            await dependencies.widgetSnapshots.refresh().value
        }
    }

    /// A button built for a slot whose doses were all logged meanwhile.
    private static func intentIsEmpty(_ intent: NotificationIntent) -> Bool {
        switch intent {
        case .take(let ids, _), .skip(let ids, _): ids.isEmpty
        default: false
        }
    }
}
