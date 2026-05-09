//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

open class DefaultConfig: EmbraceConfigurable {
	open var hangLimits: HangLimits { return HangLimits() }

	open var isSDKEnabled: Bool { return true }

	open var isBackgroundSessionEnabled: Bool { return false }

	open var isNetworkSpansForwardingEnabled: Bool { return false }

	open var isUiLoadInstrumentationEnabled: Bool { return true }

	open var isWalModeEnabled: Bool { return true }

	open var viewControllerClassNameBlocklist: [String] { return []  }

	open var uiInstrumentationCaptureHostingControllers: Bool { return false }

	open var isSwiftUiViewInstrumentationEnabled: Bool { return true }

	open var isMetricKitEnabled: Bool { return false }

	open var isMetricKitInstrumentationEnabled: Bool { return false }

	open var isMetricKitCrashCaptureEnabled: Bool { return false }

	open var metricKitCrashSignals: [String] { return [] }

	open var isMetricKitHangCaptureEnabled: Bool { return false }

	open var isMetricKitInternalMetricsCaptureEnabled: Bool { return false }

	open var spanEventsLimits: SpanEventsLimits { return SpanEventsLimits() }

	open var logsLimits: LogsLimits { return LogsLimits() }

	open var internalLogLimits: InternalLogLimits { return InternalLogLimits() }

	open var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { return []  }

	open var useLegacyUrlSessionProxy: Bool { return true }

	open var useNewStorageForSpanEvents: Bool { return true }

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
