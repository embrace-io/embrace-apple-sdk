//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCommon
@testable import EmbraceIO

class URLSessionCaptureServiceTests: XCTestCase {
    private var sut: URLSessionCaptureService!
    private var lock: DummyLock!
    private var provider: MockedURLSessionSwizzlerProvider!
    private var handler: MockURLSessionTaskHandler!

    override func setUp() {
        lock = DummyLock()
        givenURLSessionSwizzlerProvider()
    }

    func test_onInit_shouldGetSwizzlersFromProvider() {
        whenInitializingURLSessionCaptureService()
        thenProviderShouldGetAllSwizzlers()
    }

    func test_onInit_collectorIsUninstalled() {
        whenInitializingURLSessionCaptureService()
        thenCaptureServiceStatus(is: .uninstalled)
    }

    func test_onInvokeStart_statusShouldChangeToListeningAndInformHandler() {
        givenURLSessionCaptureService()
        whenInvokingStart()
        thenCaptureServiceStatus(is: .listening)
        thenHandlerShouldChangeState(to: .listening)
    }

    func test_onInvokeStop_statusShouldChangeToPausedAndInformHandler() {
        givenURLSessionCaptureService()
        whenInvokingStop()
        thenCaptureServiceStatus(is: .paused)
        thenHandlerShouldChangeState(to: .paused)
    }

    func test_onInvokeShutdown_statusShouldChangeToUninstalledAndInformHandler() {
        givenURLSessionCaptureService()
        whenInvokingShutdown()
        thenCaptureServiceStatus(is: .uninstalled)
        thenHandlerShouldChangeState(to: .uninstalled)
    }

    func test_onInstall_shouldInvokeInstallOnEverySwizzler() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [MockURLSessionSwizzler(),
                                                        MockURLSessionSwizzler(),
                                                        MockURLSessionSwizzler()])
        givenURLSessionCaptureService()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallWithFailingSwizzler_shouldContinueToInvokeInstallOnEverySwizzler() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [ThrowingURLSessionSwizzler(),
                                                        MockURLSessionSwizzler(),
                                                        ThrowingURLSessionSwizzler(),
                                                        MockURLSessionSwizzler()])
        givenURLSessionCaptureService()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallTwice_shouldInvokeSwizllersInstallOnlyOnce() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [MockURLSessionSwizzler(), MockURLSessionSwizzler()])
        givenURLSessionCaptureService()
        whenInvokingInstall()
        whenInvokingInstall()
        thenEachSwizzlerShoudHaveBeenInstalledOnce()
    }
}

private extension URLSessionCaptureServiceTests {
    func givenURLSessionSwizzlerProvider(withSwizzlers swizzlers: [any URLSessionSwizzler] = []) {
        provider = MockedURLSessionSwizzlerProvider(swizzlers: swizzlers)
    }

    func givenURLSessionCaptureService() {
        whenInitializingURLSessionCaptureService()
    }

    func whenInitializingURLSessionCaptureService() {
        lock = DummyLock()
        handler = MockURLSessionTaskHandler()
        sut = .init(lock: lock, swizzlerProvider: provider, handler: handler)
    }

    func whenInvokingStart() {
        sut.start()
    }

    func whenInvokingStop() {
        sut.stop()
    }

    func whenInvokingShutdown() {
        sut.uninstall()
    }

    func whenInvokingInstall() {
        sut.install(context: .init(appId: "myApp", sdkVersion: "0.0.0", filePathProvider: EmbraceFilePathProvider(appId: "myApp", appGroupIdentifier: "com.example.app-group")))
    }

    func thenProviderShouldGetAllSwizzlers() {
        XCTAssertTrue(provider.didGetAll)
    }

    func thenCaptureServiceStatus(is status: CaptureServiceState) {
        XCTAssertEqual(sut.status, status)
    }

    func thenHandlerShouldChangeState(to status: CaptureServiceState) {
        XCTAssertTrue(handler.didInvokeChangedState)
        XCTAssertEqual(handler.changedStateReceivedParameter, status)
    }

    func thenEachSwizzlerShouldHaveBeenInstalled() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? MockURLSessionSwizzler else { XCTFail("Swizzler should be a spy"); return }
            XCTAssertTrue(swizzler.didInstall)
        }
    }

    func thenEachSwizzlerShoudHaveBeenInstalledOnce() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? MockURLSessionSwizzler else { XCTFail("Swizzler should be a spy"); return }
            XCTAssertEqual(1, swizzler.installInvokationCount)
        }
    }
}
