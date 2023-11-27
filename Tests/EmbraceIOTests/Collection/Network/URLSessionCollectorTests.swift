//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

import XCTest
import EmbraceCommon
@testable import EmbraceIO

class DummyLock: NSLocking {
    func lock() {}
    func unlock() {}
}

class SpyURLSessionSwizzler: URLSessionSwizzler {
    // Random types and selector. This class shouldn't actually swizzle anything as methods are overriden.
    typealias ImplementationType = URLSession
    typealias BlockImplementationType = URLSession
    static var selector: Selector = #selector(UIViewController.viewDidLoad)
    var baseClass: AnyClass = URLSession.self

    required init(handler: EmbraceIO.URLSessionTaskHandler, baseClass: AnyClass) {}

    convenience init() {
        self.init(handler: MockURLSessionTaskHandler(), baseClass: Self.self)
    }

    var didInstall = false
    var installInvokationCount: Int = 0
    func install() throws {
        didInstall = true
        installInvokationCount += 1
    }

    var didSwizzleInstanceMethod = false
    func swizzleInstanceMethod(_ block: (NSString) -> NSString) throws {
        didSwizzleInstanceMethod = true
    }

    var didSwizzleClassMethod = false
    func swizzleClassMethod(_ block: (NSString) -> NSString) throws {
        didSwizzleClassMethod = true
    }
}

class ThrowingURLSessionSwizzler: SpyURLSessionSwizzler {
    override func install() throws {
        didInstall = true
        throw NSError(domain: UUID().uuidString, code: Int.random(in: 0..<Int.max))
    }
}

class MockedURLSessionSwizzlerProvider: URLSessionSwizzlerProvider {
    let swizzlers: [any URLSessionSwizzler]

    init(swizzlers: [any URLSessionSwizzler]) {
        self.swizzlers = swizzlers
    }

    var didGetAll = false
    func getAll(usingHandler handler: URLSessionTaskHandler) -> [any URLSessionSwizzler] {
        didGetAll = true
        return swizzlers
    }
}

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

    func test_collectorIsAlwaysAvailable() {
        givenURLSessionCollector()
        thenCollectorIsAvailable()
    }

    func test_onInstall_shouldInvokeInstallOnEverySwizzler() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [SpyURLSessionSwizzler(),
                                                        SpyURLSessionSwizzler(),
                                                        SpyURLSessionSwizzler()])
        givenURLSessionCollector()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallWithFailingSwizzler_shouldContinueToInvokeInstallOnEverySwizzler() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [ThrowingURLSessionSwizzler(),
                                                        SpyURLSessionSwizzler(),
                                                        ThrowingURLSessionSwizzler(),
                                                        SpyURLSessionSwizzler()])
        givenURLSessionCollector()
        whenInvokingInstall()
        thenEachSwizzlerShouldHaveBeenInstalled()
    }

    func test_onInstallTwice_shouldInvokeSwizllersInstallOnlyOnce() {
        givenURLSessionSwizzlerProvider(withSwizzlers: [SpyURLSessionSwizzler(), SpyURLSessionSwizzler()])
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
        sut.shutdown()
    }

    func whenInvokingInstall() {
        sut.install()
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

    func thenCollectorIsAvailable() {
        XCTAssertTrue(sut.isAvailable())
    }

    func thenEachSwizzlerShouldHaveBeenInstalled() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? SpyURLSessionSwizzler else { XCTFail("Swizzler should be a spy"); return }
            XCTAssertTrue(swizzler.didInstall)
        }
    }

    func thenEachSwizzlerShoudHaveBeenInstalledOnce() {
        provider.swizzlers.forEach {
            guard let swizzler = $0 as? SpyURLSessionSwizzler else { XCTFail("Swizzler should be a spy"); return }
            XCTAssertEqual(1, swizzler.installInvokationCount)
        }
    }
}
