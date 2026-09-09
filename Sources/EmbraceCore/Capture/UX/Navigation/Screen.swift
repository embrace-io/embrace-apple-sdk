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

    /// Value of the state before anything has appeared. Wire contract — the backend reads this
    /// string, so it must not be reworded.
    static let initializing = Screen("Initializing")

    /// Value of the state while the app is backgrounded. Wire contract, as above.
    static let backgrounded = Screen("Backgrounded")

    /// Names the framework gives its own meaning to, which a caller must not be able to mint.
    ///
    /// Equality is by name, so a screen declared with one of these is indistinguishable from the
    /// sentinel downstream: the state primitive would collapse the real transition into the
    /// caller's, and a session where the app genuinely backgrounded would report that it never did.
    static func isReserved(_ name: String) -> Bool {
        name == initializing.name || name == backgrounded.name
    }
}
