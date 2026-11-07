//
//  ShortcutContext.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.10.2026.
//

import Foundation

/// What every shortcut needs from the app, read the same way.
@MainActor
enum ShortcutContext {

    /// Reading `launcher` opens the store if Siri launched the app.
    static func dependencies() throws -> AppDependencies {
        guard let dependencies = AppDelegate.shared?.launcher.dependencies else {
            throw ShortcutError.storeUnavailable
        }
        return dependencies
    }

    /// With Plekio's Face ID lock on, Siri says no medication names or readings:
    /// unlike the screen, an answer is heard by anyone nearby.
    static var hidesDetails: Bool {
        AppDelegate.shared?.launcher.dependencies?.appLock.isEnabled ?? true
    }
}
