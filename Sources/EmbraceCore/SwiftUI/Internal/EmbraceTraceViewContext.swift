//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import OpenTelemetryApi

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
private struct EmbraceTraceEnvironmentKey: EnvironmentKey {
    static let defaultValue: EmbraceTraceViewContext = EmbraceTraceViewContext()
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension EnvironmentValues {
    var embraceTraceViewContext: EmbraceTraceViewContext {
        get { self[EmbraceTraceEnvironmentKey.self] }
        set { self[EmbraceTraceEnvironmentKey.self] = newValue }
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class EmbraceTraceViewContext {
    // we expect this to only and always be called on the main queue.
    var firstCycleSpan: Span? = nil
}
