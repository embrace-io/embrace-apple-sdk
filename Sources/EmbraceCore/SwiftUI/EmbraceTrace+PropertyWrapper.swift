import Foundation

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct EmbraceTraceState<Value>: DynamicProperty {
    @State private var value: Value
    private var name: String
    private var phase = EmbraceTracePhase.shared
    
    public var wrappedValue: Value {
        get { value }
        nonmutating set {
            let span = phase.startSpan("STATE-SET-\(name)", root: true)
            value = newValue
            phase.onNextCycle {
                phase.endSpan(span, root: true)
            }
        }
    }
    
    public init(wrappedValue initialValue: Value, _ name: String) {
        self.value = initialValue
        self.name = name
    }
    
    public var projectedValue: Binding<Value> {
        $value
    }
    
    
    public func update() {
        let span = phase.startSpan("STATE-UPDATE-\(name)", root: true)
        phase.onNextCycle {
            phase.endSpan(span, root: true)
        }
    }
    
}
#endif
