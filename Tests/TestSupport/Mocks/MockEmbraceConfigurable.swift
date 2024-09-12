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
        internalLogLimits: InternalLogLimits = InternalLogLimits(),
        networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = [],
        updateCompletionParamDidUpdate: Bool = false,
        updateCompletionParamError: Error? = nil
    ) {
        self._isSDKEnabled = isSDKEnabled
        self._isBackgroundSessionEnabled = isBackgroundSessionEnabled
        self._isNetworkSpansForwardingEnabled = isNetworkSpansForwardingEnabled
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

    public let updateExpectation = XCTestExpectation(description: "update called")
    public var updateCompletionParamDidUpdate: Bool
    public var updateCompletionParamError: Error?
    public func update(completion: @escaping (Bool, (any Error)?) -> Void) {
        updateExpectation.fulfill()
        completion(updateCompletionParamDidUpdate, updateCompletionParamError)
    }
}
