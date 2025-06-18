//
//  EmbraceTraceViewState.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// A state container for tracking SwiftUI View lifecycle events within `EmbraceTraceView`.
///
/// This class is specifically designed to persist state across SwiftUI View updates without
/// triggering additional redraws. By using reference semantics (class), only the reference
/// to this object is tracked by SwiftUI's observation system, not its internal property changes.
///
/// ## Architecture Note
///
/// **Important**: This must remain a `class`, not a `struct`. Converting to a struct would
/// cause SwiftUI to trigger View updates whenever properties change, leading to infinite
/// update cycles or performance issues.
///
/// ## Thread Safety
///
/// This class is not thread-safe. Ensure all access occurs on the main thread, which is
/// typical for SwiftUI View lifecycle events.
final class EmbraceTraceViewState<Value: Equatable> {
    // MARK: - Initialization Tracking

    /// The timestamp when the view was first initialized.
    var initializeTime: Date?

    /// Count of how many times the view has been initialized.
    var initialize: Int = 0

    // MARK: - Body Evaluation Tracking

    /// The timestamp when the view's body was last evaluated.
    var bodyTime: Date?

    /// Count of how many times the view's body has been evaluated.
    var body: Int = 0

    // MARK: - Appearance Tracking

    /// The timestamp when the view last appeared on screen.
    var appearTime: Date?

    /// Count of how many times the view has appeared.
    var appear: Int = 0

    // MARK: - Disappearance Tracking

    /// The timestamp when the view last disappeared from screen.
    var disappearTime: Date?

    /// Count of how many times the view has disappeared.
    var disappear: Int = 0

    // MARK: - Content Complete

    /// The timestamp when the user flagged content as complete.
    var contentCompleteTime: Date?

    /// Count of how many times the user flagged content as complete.
    var contentComplete: Int = 0

    /// The current value tracked for content completion.
    var contentCompleteValue: Value?

    /// A flag to indicate if we've cached the first value.
    var contentCompleteStoredFirstValue: Bool = false

    // MARK: - Debugging

    /// Returns a formatted string representation of the current state.
    ///
    /// Useful for debugging and logging purposes.
    ///
    /// - Returns: A multi-line string containing all tracked metrics
    public func debugDescription() -> String {
        return """
        EmbraceTraceViewState Debug Info:
        ├─ Initialize: \(initialize) times, first at \(initializeTime?.description ?? "never")
        ├─ Body: \(body) times, last at \(bodyTime?.description ?? "never")
        ├─ Appear: \(appear) times, last at \(appearTime?.description ?? "never")
        └─ Disappear: \(disappear) times, last at \(disappearTime?.description ?? "never")
        """
    }
}
