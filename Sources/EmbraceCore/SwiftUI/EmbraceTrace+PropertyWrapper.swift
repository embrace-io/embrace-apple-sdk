#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// A property wrapper that integrates with EmbraceTrace to measure state changes.
/// Wraps a value of type `Value` and emits tracing spans when the state is updated.
/// You can replace any `@State` with `@EmbraceTraceState(<name>)` to add
/// tracing to state changes.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct EmbraceTraceState<Value>: DynamicProperty {
    /// The underlying state value managed by SwiftUI.
    @State private var value: Value
    /// The name identifier used for tracing spans.
    private var name: String
    /// Shared tracing phase manager for cycling spans.
    private var phase = EmbraceTracePhase.shared
    
    /// The current value of the property wrapper.
    /// Setting this value emits a tracing span and updates the state.
    public var wrappedValue: Value {
        get { value }
        nonmutating set {
            // TODO: name this correctly
            phase.cycledSpan("emb-view-state-set-\(name)")
            value = newValue
        }
    }
    
    /// Creates a new `EmbraceTraceState` property wrapper.
    /// - Parameters:
    ///   - initialValue: The initial value for the state.
    ///   - name: A unique name used to identify tracing spans.
    public init(wrappedValue initialValue: Value, _ name: String) {
        self.value = initialValue
        self.name = name
    }
    
    /// A binding to the underlying value, allowing two-way updates in SwiftUI views
    /// Same as the projectedValue for `@State`.
    public var projectedValue: Binding<Value> {
        $value
    }
    
    /// Called during view updates to emit a tracing span for state cycles.
    public func update() {
        // TODO: name this correctly
        phase.cycledSpan("emb-view-state-upate-\(name)")
    }
    
}
#endif
