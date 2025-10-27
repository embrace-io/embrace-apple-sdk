//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// This protocol is used to add configuration to the runtime of the SDK
/// It is used to configure the ongoing behavior of the SDK
@objc public protocol EmbraceConfigurable {
    var isSDKEnabled: Bool { get }

    var isBackgroundSessionEnabled: Bool { get }

    var isNetworkSpansForwardingEnabled: Bool { get }

    var isUiLoadInstrumentationEnabled: Bool { get }

    var isWalModeEnabled: Bool { get }

    var viewControllerClassNameBlocklist: [String] { get }

    var uiInstrumentationCaptureHostingControllers: Bool { get }

    var isSwiftUiViewInstrumentationEnabled: Bool { get }

    var isMetricKitEnabled: Bool { get }

    var isMetricKitCrashCaptureEnabled: Bool { get }

    var metricKitCrashSignals: [String] { get }

    var isMetricKitHangCaptureEnabled: Bool { get }

    var spanEventsLimits: SpanEventsLimits { get }

    var logsLimits: LogsLimits { get }

    var internalLogLimits: InternalLogLimits { get }

    var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { get }

    var hangLimits: HangLimits { get }

    var useLegacyUrlSessionProxy: Bool { get }

    /// Tell the configurable implementation it should update if possible.
    /// - Parameters:
    ///     - completion: A completion block that takes two parameters (didChange, error). Completion block should pass `true`
    ///     if the configuration now has different values and `false` if not in the case of an error updating, the completion block should
    ///     return `false` and an Error object describing the issue.
    func update(completion: @escaping (Bool, Error?) -> Void)
}
