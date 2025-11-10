//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import EmbraceCore
import EmbraceCrash
import Foundation
import TestSupport
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO
@testable import EmbraceStorageInternal
@testable import EmbraceUploadInternal

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

class PerformanceLogicalWritesTests: XCTestCase {

    struct TestEvent: EmbraceSpanEvent {
        let name: String = EmbraceIdentifier.random.stringValue
        let timestamp: Date
        let attributes: [String: String]
    }

    private func randomString(_ length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    func test_measureLogicalWrites() {

        let storage: EmbraceStorage! = try? EmbraceStorage.createInDiskDb(fileName: UUID().uuidString, journalMode: .wal)

        measure(metrics: [XCTStorageMetric()]) {

            let startDate = Date()

            let sem = DispatchSemaphore(value: 0)
            _ = storage.addSession(
                id: TestConstants.sessionId,
                processId: ProcessIdentifier.current,
                state: .foreground,
                traceId: TestConstants.traceId,
                spanId: TestConstants.spanId,
                startTime: startDate,
            ) {
                sem.signal()
            }
            sem.wait()

            let span: EmbraceSpan! = storage.upsertSpan(
                id: TestConstants.spanId,
                name: "emb-session",
                traceId: TestConstants.traceId,
                type: SpanType.session,
                data: Data(),
                startTime: startDate
            )

            for index in (1...200) {
                storage.addEventsToSpan(
                    id: span.id,
                    traceId: span.traceId,
                    events: [
                        TestEvent(
                            timestamp: startDate.addingTimeInterval(Double(index)),
                            attributes: [
                                "attribute.1": randomString(Int.random(in: 100...1000)),
                                "message": randomString(Int.random(in: 100...1000))
                            ]
                        )
                    ]
                )
            }

            storage.coreData.save()
        }
    }
}

extension EmbraceStorage {

    @discardableResult
    public func addSession(
        id: EmbraceIdentifier,
        processId: EmbraceIdentifier,
        state: SessionState,
        traceId: String,
        spanId: String,
        startTime: Date,
        endTime: Date? = nil,
        lastHeartbeatTime: Date? = nil,
        crashReportId: String? = nil,
        coldStart: Bool = false,
        cleanExit: Bool = false,
        appTerminated: Bool = false
    ) async -> EmbraceSession? {
        await withCheckedContinuation { continuation in
            var session: EmbraceSession? = nil
            session = addSession(
                id: id, processId: processId, state: state, traceId: traceId, spanId: spanId, startTime: startTime
            ) {
                continuation.resume(returning: session)
            }
        }
    }

}
