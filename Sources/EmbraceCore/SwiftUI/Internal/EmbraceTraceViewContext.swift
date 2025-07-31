//
//  EmbraceTraceViewContext.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import SwiftUI

/// The environment key used to store a single `EmbraceTraceViewContext` instance
/// throughout the SwiftUI view hierarchy.
///
/// This context object tracks the “root” span for a view’s render cycle so that:
///  - All child spans (body, appear/disappear) can nest under this single parent
///  - The parent span automatically ends at the end of the cycle
///
/// Without this context, each render tick would spawn disjoint spans instead of a
/// cohesive grouping per SwiftUI evaluation pass.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
private struct EmbraceTraceEnvironmentKey: EnvironmentKey {
    static let defaultValue: EmbraceTraceViewContext = EmbraceTraceViewContext()
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension EnvironmentValues {
    /// Provides access to the shared `EmbraceTraceViewContext` for the current view subtree.
    var embraceTraceViewContext: EmbraceTraceViewContext {
        get { self[EmbraceTraceEnvironmentKey.self] }
        set { self[EmbraceTraceEnvironmentKey.self] = newValue }
    }
}

/// Holds the “first cycle” span for a SwiftUI view’s lifecycle.
///
/// - `firstCycleSpan` is set at the beginning of a new render tick and cleared
///   once the run loop advances. This ensures that nested spans (body, appear,
///   disappear) all refer to the same parent span until the cycle completes.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class EmbraceTraceViewContext {
    /// The parent span for the current render cycle. Reset to `nil` once ended.
    var firstCycleSpan: Span?
}
