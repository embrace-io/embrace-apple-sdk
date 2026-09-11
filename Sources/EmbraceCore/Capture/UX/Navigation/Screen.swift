//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

/// The screen the user is currently on, as recorded by the `screen-automatic` state.
///
/// Equality is by name alone, which is what the state primitive uses to suppress duplicate
/// transitions: navigating between two different containers that resolve to the same name is a
/// dropped transition, not a recorded one.
struct Screen: StateValue {

    /// The name written verbatim to `emb.state.new_value` / `emb.state.initial_value`.
    let name: String

    var stateDescription: String { name }

    init(_ name: String) {
        self.name = name
    }

    /// Value of the state before any screen has appeared
    ///
    /// TODO: figure out a better value or a better system for these cases. Aling with other platforms.
    static let initializing = Screen("Initializing")

    /// Value of the state while the app is backgrounded, as above.
    ///
    /// TODO: figure out a better value or a better system for these cases. Aling with other platforms.
    static let backgrounded = Screen("Backgrounded")

    /// User created screens named one of the above will be dropped.
    /// This method serves as a check when a screen span is emited to make sure the screen isn't named a reserve word.
    static func isReserved(_ name: String) -> Bool {
        name == initializing.name || name == backgrounded.name
    }
}
