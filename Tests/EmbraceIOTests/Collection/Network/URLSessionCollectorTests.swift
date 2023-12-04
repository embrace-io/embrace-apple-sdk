//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCommon
@testable import EmbraceIO

class URLSessionCollectorTests: XCTestCase {
    private var sut: URLSessionCollector!
    private var lock: DummyLock!
    private var provider: MockedURLSessionSwizzlerProvider!
    private var handler: MockURLSessionTaskHandler!

    override func setUp() {
        lock = DummyLock()
        givenURLSessionSwizzlerProvider()
    }

    func test_onInit_shouldGetSwizzlersFromProvider() {
        whenInitializingURLSessionCollector()
        thenProviderShouldGetAllSwizzlers()
    }

    func test_onInit_collectorIsUninstalled() {
        whenInitializingURLSessionCollector()
        thenCollectorStatus(is: .uninstalled)
    }

    func test_onInvokeStart_statusShouldChangeToListeningAndInformHandler() {
        givenURLSessionCollector()
        whenInvokingStart()
        thenCollectorStatus(is: .listening)
        thenHandlerShouldChangeState(to: .listening)
    }

    func test_onInvokeStop_statusShouldChangeToPausedAndInformHandler() {
        givenURLSessionCollector()
        whenInvokingStop()
        thenCollectorStatus(is: .paused)
        thenHandlerShouldChangeState(to: .paused)
    }

    func test_onInvokeShutdown_statusShouldChangeToUninstalledAndInformHandler() {
        givenURLSessionCollector()
        whenInvokingShutdown()
        thenCollectorStatus(is: .uninstalled)
        thenHandlerShouldChangeState(to: .uninstalled)
    }

    func test_onInstall_shouldInvokeInstallOnEverySwizzler() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [MockURLSessionSwizzler(),
                                                        MockURLSessionSwizzler(),
                                                        MockURLSessionSwizzler()])
        givenURLSessionCollector()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallWithFailingSwizzler_shouldContinueToInvokeInstallOnEverySwizzler() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [ThrowingURLSessionSwizzler(),
                                                        MockURLSessionSwizzler(),
                                                        ThrowingURLSessionSwizzler(),
                                                        MockURLSessionSwizzler()])
        givenURLSessionCollector()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallTwice_shouldInvokeSwizllersInstallOnlyOnce() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [MockURLSessionSwizzler(), MockURLSessionSwizzler()])
        givenURLSessionCollector()
        whenInvokingInstall()
        whenInvokingInstall()
        thenEachSwizzlerShoudHaveBeenInstalledOnce()
    }
}

private extension URLSessionCollectorTests {
    func givenURLSessionSwizzlerProvider(withSwizzlers swizzlers: [any URLSessionSwizzler] = []) {
        provider = MockedURLSessionSwizzlerProvider(swizzlers: swizzlers)
    }

    func givenURLSessionCollector() {
        whenInitializingURLSessionCollector()
    }

    func whenInitializingURLSessionCollector() {
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

    func thenCollectorStatus(is status: CollectorState) {
        XCTAssertEqual(sut.status, status)
    }

    func thenHandlerShouldChangeState(to status: CollectorState) {
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
