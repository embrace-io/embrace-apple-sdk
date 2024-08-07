//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

/// The EmbraceType used in Log telemetry
public struct LogType: EmbraceType {
    public let primary: PrimaryType
    public let secondary: String?

    public init(primary: PrimaryType, secondary: String?) {
        self.primary = primary
        self.secondary = secondary
    }
}
