//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration

public class EditableConfig: EmbraceConfigurable {
    public var isSDKEnabled: Bool = true

    public var isBackgroundSessionEnabled: Bool = false

    public var isNetworkSpansForwardingEnabled: Bool = false

    public var internalLogLimits = InternalLogLimits()

    public var networkPayloadCaptureRules = [NetworkPayloadCaptureRule]()

    public func update(completion: (Bool, (any Error)?) -> Void) {
        completion(false, nil)
    }

    public init(
        isSdkEnabled: Bool = true,
        isBackgroundSessionEnabled: Bool = false,
        isNetworkSpansForwardingEnabled: Bool = false,
        internalLogLimits: InternalLogLimits = InternalLogLimits(),
        networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = []
    ) {
        self.isSDKEnabled = isSdkEnabled
        self.isBackgroundSessionEnabled = isBackgroundSessionEnabled
        self.isNetworkSpansForwardingEnabled = false
        self.internalLogLimits = internalLogLimits
        self.networkPayloadCaptureRules = networkPayloadCaptureRules
    }
}

extension EmbraceConfigurable where Self == DefaultConfig {
    public static var editable: EmbraceConfigurable {
        return EditableConfig()
    }
}
