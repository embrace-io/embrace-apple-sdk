//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceConfigInternal
import EmbraceConfiguration
import XCTest

class MockEmbraceConfigurable: EmbraceConfigurable {
    private var _isSDKEnabled: Bool = false
    let isSDKEnabledExpectation = XCTestExpectation(description: "isSDKEnabled called")
    var isSDKEnabled: Bool {
        get {
            isSDKEnabledExpectation.fulfill()
            return _isSDKEnabled
        }
        set {
            _isSDKEnabled = newValue
        }
    }

    private var _isBackgroundSessionEnabled: Bool = false
    let isBackgroundSessionEnabledExpectation = XCTestExpectation(description: "isBackgroundSessionEnabled called")
    var isBackgroundSessionEnabled: Bool {
        get {
            isBackgroundSessionEnabledExpectation.fulfill()
            return _isBackgroundSessionEnabled
        }
        set {
            _isBackgroundSessionEnabled = newValue
        }
    }

    private var _isNetworkSpansForwardingEnabled: Bool = false
    let isNetworkSpansForwardingEnabledExpectation = XCTestExpectation(
        description: "isNetworkSpansForwardingEnabled called" )
    var isNetworkSpansForwardingEnabled: Bool {
        get {
            isNetworkSpansForwardingEnabledExpectation.fulfill()
            return _isNetworkSpansForwardingEnabled
        }
        set {
            _isNetworkSpansForwardingEnabled = newValue
        }
    }

    private var _internalLogLimits: InternalLogLimits = InternalLogLimits()
    let internalLogLimitsExpectation = XCTestExpectation(description: "internalLogLimits called")
    var internalLogLimits: InternalLogLimits {
        get {
            internalLogLimitsExpectation.fulfill()
            return _internalLogLimits
        }
        set {
            _internalLogLimits = newValue
        }
    }

    private var _networkPayloadCaptureRules: [NetworkPayloadCaptureRule] = []
    let networkPayloadCaptureRulesExpectation = XCTestExpectation(description: "networkPayloadCaptureRules called")
    var networkPayloadCaptureRules: [NetworkPayloadCaptureRule] {
        get {
            networkPayloadCaptureRulesExpectation.fulfill()
            return _networkPayloadCaptureRules
        }
        set {
            _networkPayloadCaptureRules = newValue
        }
    }

    let updateExpectation = XCTestExpectation(description: "update called")
    func update() {
        updateExpectation.fulfill()
    }
}
