//
//  DoseFeedback.swift
//  Plekio
//
//  Created by Edward Gasparian on 26.09.2026.
//

import SwiftUI

// MARK: - DoseFeedback

/// The haptic for a change in the day's doses, decided in one place for every way
/// a dose gets logged: card, hero card, sheet, undo banner, notification.
nonisolated enum DoseFeedback {

    typealias Statuses = [PillDose.ID: DoseStatus]

    static func statuses(of pills: [PillDose]) -> Statuses {
        Dictionary(pills.map { ($0.id, $0.status) }, uniquingKeysWith: { _, last in last })
    }

    /// Nil when the doses themselves changed (another day, a course edit): that is not the user logging.
    static func feedback(from old: Statuses, to new: Statuses) -> SensoryFeedback? {
        guard Set(old.keys) == Set(new.keys) else { return nil }

        let changed = new.filter { old[$0.key] != $0.value }.values
        if changed.contains(where: \.isTaken) { return .success }
        if changed.contains(where: \.isSkipped) { return .warning }
        return changed.isEmpty ? nil : .impact(weight: .light)
    }
}

// MARK: - View+DoseFeedback

extension View {

    /// Plays DoseFeedback whenever a status among `pills` changes.
    func doseFeedback(for pills: [PillDose]) -> some View {
        sensoryFeedback(trigger: DoseFeedback.statuses(of: pills)) { old, new in
            DoseFeedback.feedback(from: old, to: new)
        }
    }
}
