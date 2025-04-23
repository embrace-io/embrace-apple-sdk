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
        internalLogLimits: InternalLogLimits = InternalLogLimits(),
        networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = [],
        isMetricKitEnabeld: Bool = false,
        updateCompletionParamDidUpdate: Bool = false,
        updateCompletionParamError: Error? = nil
    ) {
        self._isSDKEnabled = isSDKEnabled
        self._isBackgroundSessionEnabled = isBackgroundSessionEnabled
        self._isNetworkSpansForwardingEnabled = isNetworkSpansForwardingEnabled
        self._isUiLoadInstrumentationEnabled = isUiLoadInstrumentationEnabled
        self._internalLogLimits = internalLogLimits
        self._networkPayloadCaptureRules = networkPayloadCaptureRules
        self._isMetricKitEnabled = isMetricKitEnabeld
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

    public var updateCallCount = 0
    public var updateCompletionParamDidUpdate: Bool
    public var updateCompletionParamError: Error?
    public func update(completion: @escaping (Bool, (any Error)?) -> Void) {
        updateCallCount += 1
        completion(updateCompletionParamDidUpdate, updateCompletionParamError)
    }
}
