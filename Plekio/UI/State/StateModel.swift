//
//  StateModel.swift
//  Plekio
//
//  Created by Edward Gasparian on 11.11.2026.
//

import SwiftUI

/// An `@Observable` model the view owns, built once, like `@StateObject`.
/// `@State(initialValue:)` would run the factory every time the parent rebuilds the
/// view (MainTabView does on each tab switch) and throw the result away: each time a
/// store read and new subscriptions for nothing.
@propertyWrapper
struct StateModel<Model: AnyObject & Observable>: DynamicProperty {

    @State private var box: Box

    init(wrappedValue make: @autoclosure @escaping () -> Model) {
        _box = State(initialValue: Box(make))
    }

    var wrappedValue: Model { box.model }

    /// `$viewModel.draft` as a binding, as with `@StateObject`.
    var projectedValue: Bindable<Model> { Bindable(box.model) }

    /// Only the first box is kept by `@State`; the model is made on first read.
    private final class Box {
        private let make: () -> Model
        private var made: Model?

        init(_ make: @escaping () -> Model) { self.make = make }

        var model: Model {
            if let made { return made }
            let model = make()
            made = model
            return model
        }
    }
}
