//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

final public class DefaultConfig: EmbraceConfigurable {
    public let hangLimits: HangLimits = HangLimits()

    public let isSDKEnabled: Bool = true

    public let isBackgroundSessionEnabled: Bool = false

    public let isNetworkSpansForwardingEnabled: Bool = false

    public let isUiLoadInstrumentationEnabled: Bool = true

    public let isWalModeEnabled: Bool = true

    public let viewControllerClassNameBlocklist: [String] = []

    public let uiInstrumentationCaptureHostingControllers: Bool = false

    public let isSwiftUiViewInstrumentationEnabled: Bool = true

    public let isMetricKitEnabled: Bool = false

    public let isMetricKitInstrumentationEnabled: Bool = false

    public let isMetricKitCrashCaptureEnabled: Bool = false

    public let metricKitCrashSignals: [String] = []

    public let isMetricKitHangCaptureEnabled: Bool = false

    public var isMetricKitInternalMetricsCaptureEnabled: Bool = false

    public let spanEventsLimits = SpanEventsLimits()

    public let logsLimits = LogsLimits()

    public let internalLogLimits = InternalLogLimits()

    public let networkPayloadCaptureRules = [NetworkPayloadCaptureRule]()

    public let useLegacyUrlSessionProxy = false

    public let useNewStorageForSpanEvents = false

    public func update(completion: (Bool, (any Error)?) -> Void) {
        completion(false, nil)
    }

    public init() {}
}

extension EmbraceConfigurable where Self == DefaultConfig {
    public static var `default`: EmbraceConfigurable {
        return DefaultConfig()
    }
}
