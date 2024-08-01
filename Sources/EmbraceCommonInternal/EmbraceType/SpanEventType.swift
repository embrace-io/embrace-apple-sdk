//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// The EmbraceType used in Tracing telemetry, specifically on SpanEvent items.
public struct SpanEventType: EmbraceType {
    public let primary: PrimaryType
    public let secondary: String?

    public init(primary: PrimaryType, secondary: String?) {
        self.primary = primary
        self.secondary = secondary
    }
}
