//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

/// Default `EmbraceConfigurable` implementation providing Embrace's built-in configuration values.
public class DefaultConfig: EmbraceConfigurable {
    public var hangLimits: HangLimits = HangLimits()

    public let isSDKEnabled: Bool = true

    public let isBackgroundSessionEnabled: Bool = false

    public let isNetworkSpansForwardingEnabled: Bool = false

    public let isUiLoadInstrumentationEnabled: Bool = true

    public var isWalModeEnabled: Bool = true

    public let viewControllerClassNameBlocklist: [String] = []

    public let uiInstrumentationCaptureHostingControllers: Bool = false

    public let isSwiftUiViewInstrumentationEnabled: Bool = true

    public let isMetricKitEnabled: Bool = true

    public var isMetricKitInstrumentationEnabled: Bool = false

    public var isMetricKitCrashCaptureEnabled: Bool = true

    public var metricKitCrashSignals: [String] = ["SIGKILL"]

    public var isMetricKitHangCaptureEnabled: Bool = false

    public var isMetricKitInternalMetricsCaptureEnabled: Bool = false

    public let spanEventTypeLimits = SpanEventTypeLimits()

    public let logSeverityLimits = LogSeverityLimits()

    public let internalLogLimits = InternalLogLimits()

    public let networkPayloadCaptureRules = [NetworkPayloadCaptureRule]()

    public let useLegacyUrlSessionProxy = false

    public let useNewStorageForSpanEvents = false

    public let userSessionMaxDuration: TimeInterval = UserSessionSemantics.defaultMaxDurationSeconds

    public let userSessionInactivityTimeout: TimeInterval = UserSessionSemantics.defaultInactivityTimeoutSeconds

    public let traceparentInjectionEnabled: Bool = false

    public func update(completion: (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public init() {}
}

extension EmbraceConfigurable where Self == DefaultConfig {
    /// A `DefaultConfig` instance exposed as an `EmbraceConfigurable`.
    public static var `default`: EmbraceConfigurable {
        return DefaultConfig()
    }
}
