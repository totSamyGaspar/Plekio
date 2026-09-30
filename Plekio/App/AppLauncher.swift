//
//  AppLauncher.swift
//  Plekio
//
//  Created by Edward Gasparian on 30.09.2026.
//

import Foundation
import Observation

/// Opens the store before the app's graph exists. When it can't be opened the app
/// stays on the recovery screen: nothing is shown, written or rescheduled, so the
/// reminders already queued keep coming and the data on disk stays as it was.
@Observable
@MainActor
final class AppLauncher {

    enum State {
        case ready(AppDependencies)
        case failed(any Error)
    }

    private(set) var state: State

    private let location: StorageLocation
    private let open: @MainActor (StorageLocation) throws -> AppDependencies

    // MARK: - Init

    init(location: StorageLocation, open: @escaping @MainActor (StorageLocation) throws -> AppDependencies) {
        self.location = location
        self.open = open
        state = Self.attempt(open, at: location)
    }

    var dependencies: AppDependencies? {
        if case .ready(let dependencies) = state { return dependencies }
        return nil
    }

    /// For the support email; the user sees a plain explanation instead.
    var failureDetails: String? {
        if case .failed(let error) = state { return String(describing: error) }
        return nil
    }

    // MARK: - Recovery

    /// Opens again: a locked device or a full disk may have cleared. Nothing when already open.
    func retry() {
        guard dependencies == nil else { return }
        state = Self.attempt(open, at: location)
        // Opened while the app is active: no scene change will top up the reminders.
        dependencies?.reminderSync.sync()
    }

    /// The last resort, after the user confirms: sets the store aside (never deletes
    /// it) and opens an empty one.
    func startFresh() {
        do {
            try StoreBackup(location: location).setAsideStore()
        } catch {
            state = .failed(error)
            return
        }
        retry()
    }

    private static func attempt(_ open: @MainActor (StorageLocation) throws -> AppDependencies, at location: StorageLocation) -> State {
        do {
            return .ready(try open(location))
        } catch {
            return .failed(error)
        }
    }
}
