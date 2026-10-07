//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// App code that runs on the main thread while `Embrace.start()` is still in progress must be able to flush
/// the global tracer provider. Span work queued at that point waits for `start()` to finish, so a flush that
/// waited behind it would hang the main thread forever.
final class StartupForceFlushTests: XCTestCase {

    /// Capture service that flushes the global tracer provider when it's started.
    final class FlushingCaptureService: CaptureService {
        var didFlush = false

        override func onStart() {
            (OpenTelemetry.instance.tracerProvider as? TracerProviderSdk)?.forceFlush()
            didFlush = true
        }
    }

    override func setUp() {
        super.setUp()
        Embrace.client = nil
    }

    override func tearDown() {
        _ = try? Embrace.client?.stop()
        Embrace.client = nil
        super.tearDown()
    }

    func test_forceFlush_duringStart_doesNotDeadlock() throws {
        // given a capture service and a session observer that flush the global tracer provider
        let service = FlushingCaptureService()
        var observerDidFlush = false
        let observer = NotificationCenter.default.addObserver(forName: .embraceSessionDidStart, object: nil, queue: nil) { _ in
            (OpenTelemetry.instance.tracerProvider as? TracerProviderSdk)?.forceFlush()
            observerDidFlush = true
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // when the SDK is started on the main thread
        try Embrace.setup(options: Embrace.Options(appId: "myApp", captureServices: [service], crashReporter: nil)).start()

        // then both flushes returned and start finished
        XCTAssertTrue(service.didFlush)
        XCTAssertTrue(observerDidFlush)
        XCTAssertEqual(Embrace.client?.state, .started)
    }
}
