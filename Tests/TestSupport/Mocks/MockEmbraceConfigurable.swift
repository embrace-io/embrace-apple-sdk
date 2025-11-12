//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceConfigInternal
import EmbraceConfiguration
import Foundation
import XCTest

public class MockEmbraceConfigurable: EmbraceConfigurable {

    public init(
        isSDKEnabled: Bool = false,
        isBackgroundSessionEnabled: Bool = false,
        isNetworkSpansForwardingEnabled: Bool = false,
        isWalModeEnabled: Bool = true,
        isUiLoadInstrumentationEnabled: Bool = false,
        viewControllerClassNameBlocklist: [String] = [],
        uiInstrumentationCaptureHostingControllers: Bool = false,
        isSwiftUiViewInstrumentationEnabled: Bool = false,
        isMetricKitEnabled: Bool = false,
        isMetricKitCrashCaptureEnabled: Bool = false,
        metricKitCrashSignals: [String] = [],
        isMetricKitHangCaptureEnabled: Bool = false,
        isMetricKitInternalMetricsCaptureEnabled: Bool = false,
        spanEventsLimits: SpanEventsLimits = SpanEventsLimits(),
        logsLimits: LogsLimits = LogsLimits(),
        internalLogLimits: InternalLogLimits = InternalLogLimits(),
        networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = [],
        updateCompletionParamDidUpdate: Bool = false,
        updateCompletionParamError: Error? = nil,
        hangLimits: HangLimits = HangLimits(),
        useLegacyUrlSessionProxy: Bool = false,
        useNewStorageForSpanEvents: Bool = false
    ) {
        self._isSDKEnabled = isSDKEnabled
        self._isBackgroundSessionEnabled = isBackgroundSessionEnabled
        self._isNetworkSpansForwardingEnabled = isNetworkSpansForwardingEnabled
        self._isWalModeEnabled = isWalModeEnabled
        self._isUiLoadInstrumentationEnabled = isUiLoadInstrumentationEnabled
        self._viewControllerClassNameBlocklist = viewControllerClassNameBlocklist
        self._uiInstrumentationCaptureHostingControllers = uiInstrumentationCaptureHostingControllers
        self._isSwiftUiViewInstrumentationEnabled = isSwiftUiViewInstrumentationEnabled
        self._isMetricKitEnabled = isMetricKitEnabled
        self._isMetricKitCrashCaptureEnabled = isMetricKitCrashCaptureEnabled
        self._metricKitCrashSignals = metricKitCrashSignals
        self._isMetricKitHangCaptureEnabled = isMetricKitHangCaptureEnabled
        self._isMetricKitInternalMetricsCaptureEnabled = isMetricKitInternalMetricsCaptureEnabled
        self._spanEventsLimits = spanEventsLimits
        self._logsLimits = logsLimits
        self._internalLogLimits = internalLogLimits
        self._hangLimits = hangLimits
        self._networkPayloadCaptureRules = networkPayloadCaptureRules
        self._useLegacyUrlSessionProxy = useLegacyUrlSessionProxy
        self._useNewStorageForSpanEvents = useNewStorageForSpanEvents
        self.updateCompletionParamDidUpdate = updateCompletionParamDidUpdate
        self.updateCompletionParamError = updateCompletionParamError
    }

    private var _isSDKEnabled: Bool
    public let isSDKEnabledExpectation = XCTestExpectation(description: "isSDKEnabled called")
    public var isSDKEnabled: Bool {
        get {
            isSDKEnabledExpectation.fulfill()
            return _isSDKEnabled
        }
        set {
            _isSDKEnabled = newValue
        }
    }

    private var _isBackgroundSessionEnabled: Bool
    public let isBackgroundSessionEnabledExpectation = XCTestExpectation(
        description: "isBackgroundSessionEnabled called"
    )
    public var isBackgroundSessionEnabled: Bool {
        get {
            isBackgroundSessionEnabledExpectation.fulfill()
            return _isBackgroundSessionEnabled
        }
        set {
            _isBackgroundSessionEnabled = newValue
        }
    }

    private var _isWalModeEnabled: Bool
    public let isWalModeEnabledExpectation = XCTestExpectation(
        description: "isNetworkSpansForwardingEnabled called")
    public var isWalModeEnabled: Bool {
        get {
            isWalModeEnabledExpectation.fulfill()
            return _isWalModeEnabled
        }
        set {
            _isWalModeEnabled = newValue
        }
    }

    private var _isNetworkSpansForwardingEnabled: Bool
    public let isNetworkSpansForwardingEnabledExpectation = XCTestExpectation(
        description: "isNetworkSpansForwardingEnabled called")
    public var isNetworkSpansForwardingEnabled: Bool {
        get {
            isNetworkSpansForwardingEnabledExpectation.fulfill()
            return _isNetworkSpansForwardingEnabled
        }
        set {
            _isNetworkSpansForwardingEnabled = newValue
        }
    }

    private var _isUiLoadInstrumentationEnabled: Bool
    public let isUiLoadInstrumentationEnabledExpectation = XCTestExpectation(
        description: "isUiInstrumentationEnabled called")
    public var isUiLoadInstrumentationEnabled: Bool {
        get {
            isUiLoadInstrumentationEnabledExpectation.fulfill()
            return _isUiLoadInstrumentationEnabled
        }
        set {
            _isUiLoadInstrumentationEnabled = newValue
        }
    }

    private var _viewControllerClassNameBlocklist: [String]
    public let viewControllerClassNameBlocklistExpectation = XCTestExpectation(
        description: "viewControllerClassNameBlocklist called")
    public var viewControllerClassNameBlocklist: [String] {
        get {
            viewControllerClassNameBlocklistExpectation.fulfill()
            return _viewControllerClassNameBlocklist
        }
        set {
            _viewControllerClassNameBlocklist = newValue
        }
    }

    private var _uiInstrumentationCaptureHostingControllers: Bool
    public let uiInstrumentationCaptureHostingControllersExpectation = XCTestExpectation(
        description: "uiInstrumentationCaptureHostingControllers called")
    public var uiInstrumentationCaptureHostingControllers: Bool {
        get {
            uiInstrumentationCaptureHostingControllersExpectation.fulfill()
            return _uiInstrumentationCaptureHostingControllers
        }
        set {
            _uiInstrumentationCaptureHostingControllers = newValue
        }
    }

    private var _isSwiftUiViewInstrumentationEnabled: Bool
    public let isSwiftUiViewInstrumentationEnabledExpectation = XCTestExpectation(
        description: "isSwiftUiViewInstrumentationEnabled called")
    public var isSwiftUiViewInstrumentationEnabled: Bool {
        get {
            isSwiftUiViewInstrumentationEnabledExpectation.fulfill()
            return _isSwiftUiViewInstrumentationEnabled
        }
        set {
            _isSwiftUiViewInstrumentationEnabled = newValue
        }
    }

    private var _isMetricKitEnabled: Bool
    public let isMetricKitEnabledExpectation = XCTestExpectation(description: "isMetricKitEnabled called")
    public var isMetricKitEnabled: Bool {
        get {
            isMetricKitEnabledExpectation.fulfill()
            return _isMetricKitEnabled
        }
        set {
            _isMetricKitEnabled = newValue
        }
    }

    private var _isMetricKitInternalMetricsCaptureEnabled: Bool
    public let isMetricKitInternalMetricsCaptureEnabledExpectation = XCTestExpectation(description: "isMetricKitInternalMetricsCaptureEnabled called")
    public var isMetricKitInternalMetricsCaptureEnabled: Bool {
        get {
            isMetricKitInternalMetricsCaptureEnabledExpectation.fulfill()
            return _isMetricKitInternalMetricsCaptureEnabled
        }
        set {
            _isMetricKitInternalMetricsCaptureEnabled = newValue
        }
    }

    private var _isMetricKitCrashCaptureEnabled: Bool
    public let isMetricKitCrashCaptureEnabledExpectation = XCTestExpectation(
        description: "isMetricKitCrashCaptureEnabled called")
    public var isMetricKitCrashCaptureEnabled: Bool {
        get {
            isMetricKitCrashCaptureEnabledExpectation.fulfill()
            return _isMetricKitCrashCaptureEnabled
        }
        set {
            _isMetricKitCrashCaptureEnabled = newValue
        }
    }

    private var _metricKitCrashSignals: [String]
    public let metricKitCrashSignalsExpectation = XCTestExpectation(description: "metricKitCrashSignals called")
    public var metricKitCrashSignals: [String] {
        get {
            metricKitCrashSignalsExpectation.fulfill()
            return _metricKitCrashSignals
        }
        set {
            _metricKitCrashSignals = newValue
        }
    }

    private var _isMetricKitHangCaptureEnabled: Bool
    public let isMetricKitHangCaptureEnabledExpectation = XCTestExpectation(
        description: "isMetricKitHangCaptureEnabled called")
    public var isMetricKitHangCaptureEnabled: Bool {
        get {
            isMetricKitHangCaptureEnabledExpectation.fulfill()
            return _isMetricKitHangCaptureEnabled
        }
        set {
            _isMetricKitHangCaptureEnabled = newValue
        }
    }

    private var _spanEventsLimits: SpanEventsLimits
    public let spanEventsLimitsExpectation = XCTestExpectation(description: "spanEventsLimits called")
    public var spanEventsLimits: SpanEventsLimits {
        get {
            spanEventsLimitsExpectation.fulfill()
            return _spanEventsLimits
        }
        set {
            _spanEventsLimits = newValue
        }
    }

    private var _logsLimits: LogsLimits
    public let logsLimitsExpectation = XCTestExpectation(description: "logsLimits called")
    public var logsLimits: LogsLimits {
        get {
            logsLimitsExpectation.fulfill()
            return _logsLimits
        }
        set {
            _logsLimits = newValue
        }
    }

    private var _internalLogLimits: InternalLogLimits
    public let internalLogLimitsExpectation = XCTestExpectation(description: "internalLogLimits called")
    public var internalLogLimits: InternalLogLimits {
        get {
            internalLogLimitsExpectation.fulfill()
            return _internalLogLimits
        }
        set {
            _internalLogLimits = newValue
        }
    }

    private var _hangLimits: HangLimits
    public let hangLimitsExpectation = XCTestExpectation(description: "hangLimits called")
    public var hangLimits: HangLimits {
        get {
            hangLimitsExpectation.fulfill()
            return _hangLimits
        }
        set {
            _hangLimits = newValue
        }
    }

    private var _networkPayloadCaptureRules: [NetworkPayloadCaptureRule]
    public let networkPayloadCaptureRulesExpectation = XCTestExpectation(
        description: "networkPayloadCaptureRules called"
    )
    public var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] {
        get {
            networkPayloadCaptureRulesExpectation.fulfill()
            return _networkPayloadCaptureRules
        }
        set {
            _networkPayloadCaptureRules = newValue
        }
    }

    private var _useLegacyUrlSessionProxy: Bool
    public let useLegacyUrlSessionProxyExpectation = XCTestExpectation(
        description: "useLegacyUrlSessionProxy called")
    public var useLegacyUrlSessionProxy: Bool {
        get {
            useLegacyUrlSessionProxyExpectation.fulfill()
            return _useLegacyUrlSessionProxy
        }
        set {
            _useLegacyUrlSessionProxy = newValue
        }
    }

    private var _useNewStorageForSpanEvents: Bool
    public let useNewStorageForSpanEventsExpectation = XCTestExpectation(
        description: "useNewStorageForSpanEvents called")
    public var useNewStorageForSpanEvents: Bool {
        get {
            useNewStorageForSpanEventsExpectation.fulfill()
            return _useNewStorageForSpanEvents
        }
        set {
            _useNewStorageForSpanEvents = newValue
        }
    }

    public var updateCallCount = 0
    public var updateCompletionParamDidUpdate: Bool
    public var updateCompletionParamError: Error?
    public func update(completion: @escaping (Bool, (any Error)?) -> Void) {
        updateCallCount += 1
        completion(updateCompletionParamDidUpdate, updateCompletionParamError)
    }
}
