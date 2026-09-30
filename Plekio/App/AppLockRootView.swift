//
//  AppLockRootView.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.09.2026.
//

import SwiftUI

struct AppLockRootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousPhaseWasBackground = false
    @State private var hasAttemptedInitialUnlock = false

    var body: some View {
        @Bindable var lock = dependencies.appLock
        Group {
            if lock.isLocked {
                AppLockScreen(lock: lock)
            } else {
                SplashView()
            }
        }
        .appTheme()
        .background(AppPrivacyShield(isEnabled: lock.isEnabled))
        .task {
            if scenePhase == .active {
                hasAttemptedInitialUnlock = true
                await lock.unlock()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.enteredBackground() }
            // Face ID itself makes the scene inactive; a cancelled attempt must not loop.
            if phase == .active, previousPhaseWasBackground || !hasAttemptedInitialUnlock {
                hasAttemptedInitialUnlock = true
                Task { await lock.unlock() }
            }
            if phase != .inactive { previousPhaseWasBackground = phase == .background }
        }
    }

}
