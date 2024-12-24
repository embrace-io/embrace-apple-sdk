//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

public class DefaultConfig: EmbraceConfigurable {
    public let isSDKEnabled: Bool = true

    public let isBackgroundSessionEnabled: Bool = false

    public let isNetworkSpansForwardingEnabled: Bool = false

    public let isUiLoadInstrumentationEnabled: Bool = false

    public let internalLogLimits = InternalLogLimits()

    public let networkPayloadCaptureRules = [NetworkPayloadCaptureRule]()

    public func update(completion: (Bool, (any Error)?) -> Void) {
        completion(false, nil)
    }

    public init() { }
}

extension EmbraceConfigurable where Self == DefaultConfig {
    public static var `default`: EmbraceConfigurable {
        return DefaultConfig()
    }
}
