//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// The screen the user is currently on, as recorded by the `screen-automatic` state.
///
/// Equality is by name alone, which is what suppresses duplicate transitions downstream: two
/// containers resolving to the same name are one screen, not two.
struct Screen: StateValue {

    /// The name written verbatim to `emb.state.new_value` / `emb.state.initial_value`.
    let name: String

    var stateDescription: String { name }

    init(_ name: String) {
        self.name = name
    }

    /// Value of the state before any screen has appeared
    ///
    /// TODO: figure out a better value or a better system for these cases. Align with other platforms.
    static let initializing = Screen("Initializing")

    /// Value of the state while the app is backgrounded, as above.
    ///
    /// TODO: figure out a better value or a better system for these cases. Align with other platforms.
    static let backgrounded = Screen("Backgrounded")
}
