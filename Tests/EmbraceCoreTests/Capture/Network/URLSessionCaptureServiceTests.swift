//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import EmbraceCaptureService
import EmbraceCommonInternal
@testable import EmbraceCore
import TestSupport

class URLSessionCaptureServiceTests: XCTestCase {
    private var sut: URLSessionCaptureService!
    private var lock: DummyLock!
    private var provider: MockedURLSessionSwizzlerProvider!
    private var handler: MockURLSessionTaskHandler!
    private var otel: MockEmbraceOpenTelemetry!

    override func setUp() {
        lock = DummyLock()
        otel = MockEmbraceOpenTelemetry()
        givenURLSessionSwizzlerProvider()
    }

    func test_onInit_collectorIsUninstalled() {
        whenInitializingURLSessionCaptureService()
        thenCaptureServiceStatus(is: .uninstalled)
    }

    func test_onInstall_shouldGetSwizzlersFromProvider() {
        whenInitializingURLSessionCaptureService()
        whenInvokingInstall()
        thenProviderShouldGetAllSwizzlers()
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
        sut = URLSessionCaptureService(lock: lock, swizzlerProvider: provider)
    }

    func whenInvokingStart() {
        sut.start()
    }

    func whenInvokingStop() {
        sut.stop()
    }

    func whenInvokingInstall() {
        handler = MockURLSessionTaskHandler()
        sut.install(otel: otel)
    }

    func thenProviderShouldGetAllSwizzlers() {
        XCTAssertTrue(provider.didGetAll)
    }

    func thenCaptureServiceStatus(is state: CaptureServiceState) {
        XCTAssertEqual(sut.state, state)
    }

    func thenEachSwizzlerShouldHaveBeenInstalled() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? MockURLSessionSwizzler else {
                XCTFail("Swizzler should be a spy")
                return
            }

            XCTAssertTrue(swizzler.didInstall)
        }
    }

    func thenEachSwizzlerShoudHaveBeenInstalledOnce() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? MockURLSessionSwizzler else {
                XCTFail("Swizzler should be a spy")
                return
            }

            XCTAssertEqual(1, swizzler.installInvokationCount)
        }
    }
}
