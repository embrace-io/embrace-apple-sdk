//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCore
import EmbraceKSCrashSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

class PerformanceTests: XCTestCase {

    func randomAppName() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<5).compactMap { _ in letters.randomElement() })
    }

    @MainActor
    func runStartup(_ options: Embrace.Options) {

        #if !os(watchOS)
            defer {
                Embrace.client = nil
            }

            do {

                let expect = XCTestExpectation()

                try Embrace.setup(options: options).start()

                let didBecomeActiveNotif: Notification.Name
                let didFinishLaunchingNotif: Notification.Name
                #if os(macOS)
                    didBecomeActiveNotif = NSApplication.didBecomeActiveNotification
                    didFinishLaunchingNotif = NSApplication.didFinishLaunchingNotification
                #elseif os(iOS) || os(tvOS)
                    didBecomeActiveNotif = UIApplication.didBecomeActiveNotification
                    didFinishLaunchingNotif = UIApplication.didFinishLaunchingNotification
                #endif
                NotificationCenter.default.addObserver(forName: didBecomeActiveNotif, object: nil, queue: .main) { _ in
                    RunLoop.main.perform(inModes: [.common]) {
                        expect.fulfill()
                    }
                }

                NotificationCenter.default.post(name: didFinishLaunchingNotif, object: nil)
                NotificationCenter.default.post(name: didBecomeActiveNotif, object: nil)

                wait(for: [expect])

            } catch {
            }
        #endif

    }

    @MainActor
    func test_noopMainActorIsolated() {
    }

    func test_noopNotIsolated() {
    }

    @MainActor
    func test_embraceStartBasic() {
        runStartup(
            Embrace.Options(
                appId: randomAppName(),
                captureServices: .automatic,
                crashReporter: KSCrashReporter()
            )
        )
    }

    @MainActor
    func test_embraceStartSimple() {
        runStartup(
            Embrace.Options(
                appId: randomAppName(),
                captureServices: [],
                crashReporter: nil
            )
        )
    }

}

class PerformanceBacktraceTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        _ = try? Embrace.setup(options: Embrace.Options(appId: "myApp")).start()
    }

    override class func tearDown() {
        super.tearDown()
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
    }

    func test_embraceAppleStacktrace() {
        _ = Thread.callStackReturnAddresses
    }

    func test_embraceBacktrace() {
        _ = EmbraceBacktrace.backtrace()
    }

    func test_embraceBacktraceAndSymbolicate() {
        _ = EmbraceBacktrace.backtrace().threads.compactMap { thread in
            thread.callstack.frames(symbolicated: true)
        }
    }
}
