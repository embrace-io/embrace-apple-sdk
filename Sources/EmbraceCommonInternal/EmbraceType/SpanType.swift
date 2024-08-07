//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// The EmbraceType used in Tracing telemetry
public struct SpanType: EmbraceType {
    public let primary: PrimaryType

    public let secondary: String?

    public init(primary: PrimaryType, secondary: String? = nil) {
        self.primary = primary
        self.secondary = secondary
    }
}
