//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// This protocol is used to add configuration to the runtime of the SDK
/// It is used to configure the ongoing behavior of the SDK
public protocol EmbraceConfigurable: AnyObject {
    var isSDKEnabled: Bool { get }

    var isBackgroundSessionEnabled: Bool { get }

    /// Maximum duration of a user session, in seconds.
    /// - Note: Snapshotted at user-session creation; not read continuously.
    /// - Note: Valid range is `[3600, 86400]` (1h–24h). Out-of-range values fall back to the default of `12 * 3600`.
    var userSessionMaxDuration: TimeInterval { get }

    /// Inactivity timeout (no foreground part) before the user session expires, in seconds.
    /// - Note: Snapshotted at user-session creation; not read continuously.
    /// - Note: Valid range is `[30, 86400]` (30s–24h), and must be `<= userSessionMaxDuration`.
    /// Out-of-range or cross-field violations fall back to the default of `30 * 60`.
    var userSessionInactivityTimeout: TimeInterval { get }

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

    var isMetricKitInternalMetricsCaptureEnabled: Bool { get }

    var spanEventTypeLimits: SpanEventTypeLimits { get }

    var logSeverityLimits: LogSeverityLimits { get }

    var internalLogLimits: InternalLogLimits { get }

    var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { get }

    var hangLimits: HangLimits { get }

    var useLegacyUrlSessionProxy: Bool { get }

    var useNewStorageForSpanEvents: Bool { get }

    /// Tell the configurable implementation it should update if possible.
    /// - Parameters:
    ///     - completion: A completion block that takes two parameters (didChange, error). Completion block should pass `true`
    ///     if the configuration now has different values and `false` if not in the case of an error updating, the completion block should
    ///     return `false` and an Error object describing the issue.
    func update(completion: @escaping (Bool, Error?) -> Void)
}
