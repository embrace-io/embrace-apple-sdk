//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration

public class EditableConfig: EmbraceConfigurable {
    public var isSDKEnabled: Bool = true

    public var isBackgroundSessionEnabled: Bool = false

    public var isNetworkSpansForwardingEnabled: Bool = false

    public var isUiLoadInstrumentationEnabled: Bool = false

    public var internalLogLimits = InternalLogLimits()

    public var networkPayloadCaptureRules = [NetworkPayloadCaptureRule]()

    public func update(completion: (Bool, (any Error)?) -> Void) {
        completion(false, nil)
    }

    public var isMetricKitEnabled: Bool = true

    public init(
        isSdkEnabled: Bool = true,
        isBackgroundSessionEnabled: Bool = false,
        isNetworkSpansForwardingEnabled: Bool = false,
        isUiLoadInstrumentationEnabled: Bool = false,
        internalLogLimits: InternalLogLimits = InternalLogLimits(),
        networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = [],
        isMetricKitEnabled: Bool = true
    ) {
        self.isSDKEnabled = isSdkEnabled
        self.isBackgroundSessionEnabled = isBackgroundSessionEnabled
        self.isNetworkSpansForwardingEnabled = isNetworkSpansForwardingEnabled
        self.isUiLoadInstrumentationEnabled = isUiLoadInstrumentationEnabled
        self.internalLogLimits = internalLogLimits
        self.networkPayloadCaptureRules = networkPayloadCaptureRules
        self.isMetricKitEnabled = isMetricKitEnabled
    }
}

extension EmbraceConfigurable where Self == DefaultConfig {
    public static var editable: EmbraceConfigurable {
        return EditableConfig()
    }
}
