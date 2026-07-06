//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// This protocol is used to add configuration to the runtime of the SDK
/// It is used to configure the ongoing behavior of the SDK
public protocol EmbraceConfigurable: AnyObject {
    /// Whether the SDK is enabled. When `false`, the SDK stops capturing and generating data.
    var isSDKEnabled: Bool { get }

    /// Whether sessions are captured while the app is in the background.
    var isBackgroundSessionEnabled: Bool { get }

    /// Maximum duration of a user session, in seconds.
    /// - Note: Snapshotted at user-session creation; not read continuously.
    /// - Note: Valid range is `[3600, 86400]` (1h–24h). Out-of-range values fall back to `UserSessionSemantics.defaultMaxDurationSeconds`.
    var userSessionMaxDuration: TimeInterval { get }

    /// Inactivity timeout (no foreground part) before the user session expires, in seconds.
    /// - Note: Snapshotted at user-session creation; not read continuously.
    /// - Note: Valid range is `[30, 86400]` (30s–24h), and must be `<= userSessionMaxDuration`.
    /// Out-of-range or cross-field violations fall back to `UserSessionSemantics.defaultInactivityTimeoutSeconds`.
    var userSessionInactivityTimeout: TimeInterval { get }

    /// Whether network request span forwarding is enabled.
    var isNetworkSpansForwardingEnabled: Bool { get }

    /// Whether UI load instrumentation (view load timing) is enabled.
    var isUiLoadInstrumentationEnabled: Bool { get }

    /// Whether the storage database uses WAL (write-ahead logging) mode.
    var isWalModeEnabled: Bool { get }

    /// Class names of `UIViewController`s excluded from UI instrumentation.
    var viewControllerClassNameBlocklist: [String] { get }

    /// Whether SwiftUI hosting controllers are captured by UI instrumentation.
    var uiInstrumentationCaptureHostingControllers: Bool { get }

    /// Whether SwiftUI view instrumentation is enabled.
    var isSwiftUiViewInstrumentationEnabled: Bool { get }

    /// Whether the MetricKit integration is enabled.
    var isMetricKitEnabled: Bool { get }

    /// Whether crashes are captured through MetricKit.
    var isMetricKitCrashCaptureEnabled: Bool { get }

    /// Signal names captured as crashes through MetricKit.
    var metricKitCrashSignals: [String] { get }

    /// Whether hangs are captured through MetricKit.
    var isMetricKitHangCaptureEnabled: Bool { get }

    /// Whether MetricKit internal metrics are captured.
    var isMetricKitInternalMetricsCaptureEnabled: Bool { get }

    /// Limits for the span events included in the session span.
    var spanEventTypeLimits: SpanEventTypeLimits { get }

    /// Limits for the logs generated through the SDK, by severity.
    var logSeverityLimits: LogSeverityLimits { get }

    /// Limits for the logs the SDK produces about its own operation.
    var internalLogLimits: InternalLogLimits { get }

    /// Rules that determine which network payloads are captured.
    var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] { get }

    /// Limits for the app hangs captured through the SDK.
    var hangLimits: HangLimits { get }

    /// Whether span events are persisted using the new storage backend.
    var useNewStorageForSpanEvents: Bool { get }

    /// Whether a `traceparent` header is injected into captured network requests.
    var traceparentInjectionEnabled: Bool { get }

    /// Tell the configurable implementation it should update if possible.
    /// - Parameters:
    ///     - completion: A completion block that receives a `Result`. On success it carries `true`
    ///     if the configuration now has different values and `false` if not. On failure it carries an
    ///     `Error` describing the issue that prevented the update.
    func update(completion: @escaping (Result<Bool, Error>) -> Void)
}
