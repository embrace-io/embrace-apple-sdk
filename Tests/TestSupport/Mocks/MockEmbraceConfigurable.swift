//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceConfigInternal
import EmbraceConfiguration
import XCTest

public class MockEmbraceConfigurable: EmbraceConfigurable {

    public init(
        isSDKEnabled: Bool = false,
        isBackgroundSessionEnabled: Bool = false,
        isNetworkSpansForwardingEnabled: Bool = false,
        isUiLoadInstrumentationEnabled: Bool = false,
        isMetricKitEnabled: Bool = false,
        isMetricKitCrashCaptureEnabled: Bool = false,
        metricKitCrashSignals: [String] = [],
        isMetricKitHangCaptureEnabled: Bool = false,
        isSwiftUiViewInstrumentationEnabled: Bool = false,
        logsLimits: LogsLimits = LogsLimits(),
        internalLogLimits: InternalLogLimits = InternalLogLimits(),
        networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = [],
        updateCompletionParamDidUpdate: Bool = false,
        updateCompletionParamError: Error? = nil
    ) {
        self._isSDKEnabled = isSDKEnabled
        self._isBackgroundSessionEnabled = isBackgroundSessionEnabled
        self._isNetworkSpansForwardingEnabled = isNetworkSpansForwardingEnabled
        self._isUiLoadInstrumentationEnabled = isUiLoadInstrumentationEnabled
        self._isMetricKitEnabled = isMetricKitEnabled
        self._isMetricKitCrashCaptureEnabled = isMetricKitCrashCaptureEnabled
        self._metricKitCrashSignals = metricKitCrashSignals
        self._isMetricKitHangCaptureEnabled = isMetricKitHangCaptureEnabled
        self._isSwiftUiViewInstrumentationEnabled = isSwiftUiViewInstrumentationEnabled
        self._logsLimits = logsLimits
        self._internalLogLimits = internalLogLimits
        self._networkPayloadCaptureRules = networkPayloadCaptureRules
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

    private var _isNetworkSpansForwardingEnabled: Bool
    public let isNetworkSpansForwardingEnabledExpectation = XCTestExpectation(
        description: "isNetworkSpansForwardingEnabled called" )
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
    public let isUiLoadInstrumentationEnabledExpectation = XCTestExpectation(description: "isUiInstrumentationEnabled called")
    public var isUiLoadInstrumentationEnabled: Bool {
        get {
            isUiLoadInstrumentationEnabledExpectation.fulfill()
            return _isUiLoadInstrumentationEnabled
        }
        set {
            _isUiLoadInstrumentationEnabled = newValue
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

    private var _isMetricKitCrashCaptureEnabled: Bool
    public let isMetricKitCrashCaptureEnabledExpectation = XCTestExpectation(description: "isMetricKitCrashCaptureEnabled called")
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
    public let isMetricKitHangCaptureEnabledExpectation = XCTestExpectation(description: "isMetricKitHangCaptureEnabled called")
    public var isMetricKitHangCaptureEnabled: Bool {
        get {
            isMetricKitHangCaptureEnabledExpectation.fulfill()
            return _isMetricKitHangCaptureEnabled
        }
        set {
            _isMetricKitHangCaptureEnabled = newValue
        }
    }

    
    private var _isSwiftUiViewInstrumentationEnabled: Bool
    public let isSwiftUiViewInstrumentationEnabledExpectation = XCTestExpectation(description: "isSwiftUiViewInstrumentationEnabled called")
    public var isSwiftUiViewInstrumentationEnabled: Bool {
        get {
            isSwiftUiViewInstrumentationEnabledExpectation.fulfill()
            return _isSwiftUiViewInstrumentationEnabled
        }
        set {
            _isSwiftUiViewInstrumentationEnabled = newValue
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

    public var updateCallCount = 0
    public var updateCompletionParamDidUpdate: Bool
    public var updateCompletionParamError: Error?
    public func update(completion: @escaping (Bool, (any Error)?) -> Void) {
        updateCallCount += 1
        completion(updateCompletionParamDidUpdate, updateCompletionParamError)
    }
}
