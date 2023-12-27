//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import XCTest
import UIKit
import EmbraceCommon
@testable import EmbraceCore
import TestSupport

class MockUIWindowSendEventSwizzler: UIWindowSendEventSwizzler {
    var didCallInstall = false
    var installInvokationCount = 0
    override func install() throws {
        didCallInstall = true
        installInvokationCount += 1
    }

    init() { super.init(handler: MockTapCaptureServiceHandler()) }
}

class MockUIWindowSwizzlerProvider: UIWindowSwizzlerProvider {
    let swizzler: UIWindowSendEventSwizzler

    init(swizzler: UIWindowSendEventSwizzler = MockUIWindowSendEventSwizzler()) {
        self.swizzler = swizzler
    }

    var didCallGet = false
    func get(usingHandler handler: TapCaptureServiceHandler) -> UIWindowSendEventSwizzler {
        didCallGet = true
        return swizzler
    }
}

class MockTapCaptureServiceHandler: TapCaptureServiceHandler {
    var didCallHandlerCapturedEvent = false
    func handleCapturedEvent(_ event: UIEvent) {
        didCallHandlerCapturedEvent = true
    }

    var didCallChangedState = false
    var changedStateReceivedParameter: CaptureServiceState?
    func changedState(to captureServiceState: CaptureServiceState) {
        didCallChangedState = true
        changedStateReceivedParameter = captureServiceState
    }
}

final class TapCaptureServiceTests: XCTestCase {
    private var sut: TapCaptureService!
    private var provider: MockUIWindowSwizzlerProvider!
    private var handler: MockTapCaptureServiceHandler!
    private var lock: DummyLock!

    override func setUpWithError() throws {
        lock = .init()
        handler = .init()
        provider = .init()
    }

    func test_onInit_shouldGetSwizzlersFromProvider() {
        whenInitializingTapCaptureService()
        thenShouldGetSwizzlerFromProvider()
    }

    func test_onInit_collectorIsUninstalled() {
        whenInitializingTapCaptureService()
        thenCaptureServiceStatus(is: .uninstalled)
    }

    func test_onInvokeStart_statusShouldChangeToListeningAndInformHandler() {
        givenTapCaptureService()
        whenInvokingStart()
        thenCaptureServiceStatus(is: .listening)
        thenHandlerShouldChangeState(to: .listening)
    }

    func test_onInvokeStop_statusShouldChangeToPausedAndInformHandler() {
        givenTapCaptureService()
        whenInvokingStop()
        thenCaptureServiceStatus(is: .paused)
        thenHandlerShouldChangeState(to: .paused)
    }

    func test_onInvokeUninstall_statusShouldChangeToUninstalledAndInformHandler() {
        givenTapCaptureService()
        whenInvokingUninstall()
        thenCaptureServiceStatus(is: .uninstalled)
        thenHandlerShouldChangeState(to: .uninstalled)
    }

    func test_onInstall_shouldInvokeInstallOnEverySwizzler() throws {
        givenTapCaptureService()
        whenInvokingInstall()
        try thenProvidedSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallTwice_shouldInvokeSwizllersInstallOnlyOnce() throws {
        givenTapCaptureService()
        whenInvokingInstall()
        whenInvokingInstall()
        try thenProvidedSwizzlerShoudHaveBeenInstalledOnce()
    }
}

extension TapCaptureServiceTests {
    func givenTapCaptureService() {
        whenInitializingTapCaptureService()
    }

    func whenInvokingStart() {
        sut.start()
    }

    func whenInvokingInstall() {
        sut.install(context: .init(appId: "", sdkVersion: "", filePathProvider: TemporaryFilepathProvider()))
    }

    func whenInvokingStop() {
        sut.stop()
    }

    func whenInvokingUninstall() {
        sut.uninstall()
    }

    func whenInitializingTapCaptureService() {
        sut = TapCaptureService(lock: lock, handler: handler, swizzlerProvider: provider)
    }

    func thenShouldGetSwizzlerFromProvider() {
        XCTAssertTrue(provider.didCallGet)
    }

    func thenCaptureServiceStatus(is status: CaptureServiceState) {
        XCTAssertEqual(sut.captureServiceState, status)
    }

    func thenHandlerShouldChangeState(to status: CaptureServiceState) {
        XCTAssertTrue(handler.didCallChangedState)
        XCTAssertEqual(handler.changedStateReceivedParameter, status)
    }

    func thenProvidedSwizzlerShouldHaveBeenInstalled() throws {
        let swizzler = try XCTUnwrap(provider.swizzler as? MockUIWindowSendEventSwizzler)
        XCTAssertTrue(swizzler.didCallInstall)
    }

    func thenProvidedSwizzlerShoudHaveBeenInstalledOnce() throws {
        let swizzler = try XCTUnwrap(provider.swizzler as? MockUIWindowSendEventSwizzler)
        XCTAssertEqual(swizzler.installInvokationCount, 1)
    }
}

#endif
