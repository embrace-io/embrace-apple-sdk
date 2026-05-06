//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfiguration
import Foundation

public class EditableConfig: EmbraceConfigurable {

    public var hangLimits: HangLimits = HangLimits()

    public var isSDKEnabled: Bool = true

    public var isBackgroundSessionEnabled: Bool = false

    public var isNetworkSpansForwardingEnabled: Bool = false

    public var isWalModeEnabled: Bool = true

    public var isUiLoadInstrumentationEnabled: Bool = false

    public var viewControllerClassNameBlocklist: [String] = []

    public var uiInstrumentationCaptureHostingControllers: Bool = false

    public var isSwiftUiViewInstrumentationEnabled: Bool = false

    public var isMetricKitEnabled: Bool = true

    public var isMetricKitCrashCaptureEnabled: Bool = false

    public var metricKitCrashSignals: [String] = []

    public var isMetricKitHangCaptureEnabled: Bool = false

    public var isMetricKitInternalMetricsCaptureEnabled: Bool = false

    public var spanEventTypeLimits = SpanEventTypeLimits()

    public var logSeverityLimits = LogSeverityLimits()

    public var internalLogLimits = InternalLogLimits()

    public var networkPayloadCaptureRules = [NetworkPayloadCaptureRule]()

    public var useLegacyUrlSessionProxy: Bool = false

    public var useNewStorageForSpanEvents: Bool = false

    public var userSessionMaxDuration: TimeInterval = 12 * 3600

    public var userSessionInactivityTimeout: TimeInterval = 30 * 60

    public func update(completion: (Bool, (any Error)?) -> Void) {
        completion(false, nil)
    }

    public init(
        isSdkEnabled: Bool = true,
        isBackgroundSessionEnabled: Bool = false,
        isNetworkSpansForwardingEnabled: Bool = false,
        isUiLoadInstrumentationEnabled: Bool = false,
        isMetricKitEnabled: Bool = false,
        isMetricKitCrashCaptureEnabled: Bool = false,
        metricKitCrashSignals: [String] = [],
        isMetricKitHangCaptureEnabled: Bool = false,
        isMetricKitInternalMetricsCaptureEnabled: Bool = false,
        isSwiftUiViewInstrumentationEnabled: Bool = false,
        internalLogLimits: InternalLogLimits = InternalLogLimits(),
        networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = [],
        hangLimits: HangLimits = HangLimits(),
        useLegacyUrlSessionProxy: Bool = false,
        useNewStorageForSpanEvents: Bool = false,
        userSessionMaxDuration: TimeInterval = 12 * 3600,
        userSessionInactivityTimeout: TimeInterval = 30 * 60
    ) {
        self.isSDKEnabled = isSdkEnabled
        self.isBackgroundSessionEnabled = isBackgroundSessionEnabled
        self.isNetworkSpansForwardingEnabled = isNetworkSpansForwardingEnabled
        self.isUiLoadInstrumentationEnabled = isUiLoadInstrumentationEnabled
        self.isMetricKitEnabled = isMetricKitEnabled
        self.isMetricKitCrashCaptureEnabled = isMetricKitCrashCaptureEnabled
        self.metricKitCrashSignals = metricKitCrashSignals
        self.isMetricKitHangCaptureEnabled = isMetricKitHangCaptureEnabled
        self.isMetricKitInternalMetricsCaptureEnabled = isMetricKitInternalMetricsCaptureEnabled
        self.isSwiftUiViewInstrumentationEnabled = isSwiftUiViewInstrumentationEnabled
        self.internalLogLimits = internalLogLimits
        self.networkPayloadCaptureRules = networkPayloadCaptureRules
        self.hangLimits = hangLimits
        self.useLegacyUrlSessionProxy = useLegacyUrlSessionProxy
        self.useNewStorageForSpanEvents = useNewStorageForSpanEvents
        self.userSessionMaxDuration = userSessionMaxDuration
        self.userSessionInactivityTimeout = userSessionInactivityTimeout
    }
}

extension EmbraceConfigurable where Self == DefaultConfig {
    public static var editable: EmbraceConfigurable {
        return EditableConfig()
    }
}
