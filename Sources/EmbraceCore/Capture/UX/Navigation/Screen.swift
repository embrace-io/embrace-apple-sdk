//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// The screen the user is currently on, as recorded by the `screen-automatic` state.
///
/// Equality is by name **and** type, which is what suppresses duplicate transitions downstream: two
/// containers resolving to the same name are one screen, not two — while an app screen named
/// "Backgrounded" and the SDK's value of that name stay two.
struct Screen: StateValue {

    /// The name written verbatim to `emb.state.new_value` / `emb.state.initial_value`.
    let name: String

    /// `.system` for the two values below, `nil` for every screen that came from the app.
    let stateValueType: StateValueType?

    var stateDescription: String { name }

    /// A screen of the app's own: a name the developer chose or a view controller's class.
    init(_ name: String) {
        self.name = name
        self.stateValueType = nil
    }

    private init(system name: String) {
        self.name = name
        self.stateValueType = .system
    }

    /// Value of the state before any screen has appeared.
    static let initializing = Screen(system: "Initializing")

    /// Value of the state while the app is backgrounded.
    static let backgrounded = Screen(system: "Backgrounded")
}
