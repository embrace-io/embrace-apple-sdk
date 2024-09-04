//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

class DefaultConfig: EmbraceConfigurable {
    let isSDKEnabled: Bool = true

    let isBackgroundSessionEnabled: Bool = false

    let isNetworkSpansForwardingEnabled: Bool = false

    let internalLogLimits = InternalLogLimits()

    let networkPayloadCaptureRules = [NetworkPayloadCaptureRule]()

    func update() { /* No op */ }
}

extension EmbraceConfigurable {
    public static var `default`: EmbraceConfigurable {
        return DefaultConfig()
    }
}
