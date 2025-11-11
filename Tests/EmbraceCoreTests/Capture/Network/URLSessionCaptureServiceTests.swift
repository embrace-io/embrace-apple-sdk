//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore

@MainActor
class URLSessionCaptureServiceTests: XCTestCase {
    private var sut: URLSessionCaptureService!
    private var lock: DummyLock!
    private var provider: MockedURLSessionSwizzlerProvider!
    private var handler: MockURLSessionTaskHandler!
    private var otel: MockEmbraceOpenTelemetry!

    override func setUp() async throws {
        lock = DummyLock()
        otel = MockEmbraceOpenTelemetry()
        givenURLSessionSwizzlerProvider()
    }

    override func tearDown() async throws {
        sut.swizzlers.forEach {
            try? $0.unswizzleClassMethod()
            try? $0.unswizzleInstanceMethod()
        }
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
        givenURLSessionSwizzlerProvider(withSwizzlers: [
            MockURLSessionSwizzler(),
            MockURLSessionSwizzler(),
            MockURLSessionSwizzler()
        ])
        givenURLSessionCaptureService()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallWithFailingSwizzler_shouldContinueToInvokeInstallOnEverySwizzler() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [
            ThrowingURLSessionSwizzler(),
            MockURLSessionSwizzler(),
            ThrowingURLSessionSwizzler(),
            MockURLSessionSwizzler()
        ])
        givenURLSessionCaptureService()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallTwice_shouldInvokeSwizllersInstallOnlyOnce() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [MockURLSessionSwizzler(), MockURLSessionSwizzler()])
        givenURLSessionCaptureService()
        whenInvokingInstall()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalledOnce()
    }
}

extension URLSessionCaptureServiceTests {
    fileprivate func givenURLSessionSwizzlerProvider(withSwizzlers swizzlers: [any URLSessionSwizzler] = []) {
        provider = MockedURLSessionSwizzlerProvider(swizzlers: swizzlers)
    }

    fileprivate func givenURLSessionCaptureService() {
        whenInitializingURLSessionCaptureService()
    }

    fileprivate func whenInitializingURLSessionCaptureService() {
        lock = DummyLock()
        sut = URLSessionCaptureService(lock: lock, swizzlerProvider: provider)
    }

    fileprivate func whenInvokingStart() {
        sut.start()
    }

    fileprivate func whenInvokingStop() {
        sut.stop()
    }

    fileprivate func whenInvokingInstall() {
        handler = MockURLSessionTaskHandler()
        sut.install(otel: otel)
    }

    fileprivate func thenProviderShouldGetAllSwizzlers() {
        XCTAssertTrue(provider.didGetAll)
    }

    fileprivate func thenCaptureServiceStatus(is state: CaptureServiceState) {
        XCTAssertEqual(sut.state.load(), state)
    }

    fileprivate func thenEachSwizzlerShouldHaveBeenInstalled() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? MockURLSessionSwizzler else {
                XCTFail("Swizzler should be a spy")
                return
            }

            XCTAssertTrue(swizzler.didInstall)
        }
    }

    fileprivate func thenEachSwizzlerShouldHaveBeenInstalledOnce() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? MockURLSessionSwizzler else {
                XCTFail("Swizzler should be a spy")
                return
            }

            XCTAssertEqual(1, swizzler.installInvokationCount)
        }
    }
}
