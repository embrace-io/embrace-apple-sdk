//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// The screen the user is currently on, as recorded by the `screen-automatic` state.
///
/// Equality is by name **and** ``isSystemValue``, which is what suppresses duplicate transitions
/// downstream: two containers resolving to the same name are one screen, not two — while an app
/// screen named "Backgrounded" and the SDK's value of that name stay two.
struct Screen: StateValue {

    /// The name written verbatim to `emb.state.new_value` / `emb.state.initial_value`.
    let name: String

    /// `true` only for the SDK's own values declared below.
    let isSystemValue: Bool

    var stateDescription: String { name }

    /// A screen of the app's own: a name the developer chose or a view controller's class.
    ///
    /// Declaring it also suppresses the memberwise initializer, which is what stops an app-supplied
    /// name from being marked as a system value.
    init(_ name: String) {
        self.name = name
        self.isSystemValue = false
    }

    /// Private on purpose: only the values below are system values, whatever a screen is named.
    private init(system name: String) {
        self.name = name
        self.isSystemValue = true
    }

    /// Value of the state before any screen has appeared.
    static let initializing = Screen(system: "Initializing")

    /// Value of the state while the app is backgrounded.
    static let backgrounded = Screen(system: "Backgrounded")

    /// Compared by what is written, not by every stored property, so a property added later cannot
    /// silently widen this and split one screen into two.
    static func == (lhs: Screen, rhs: Screen) -> Bool {
        lhs.stateDescription == rhs.stateDescription && lhs.isSystemValue == rhs.isSystemValue
    }
}
