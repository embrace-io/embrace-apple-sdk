//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore

#if canImport(EmbraceKSCrashBacktraceSupport)
    import EmbraceKSCrashBacktraceSupport
#endif

// MARK: - Availability Tests (runs first alphabetically)

final class EmbraceBacktraceAvailabilityTests: XCTestCase {

    func test_backtrace_isAvailable_returnsFalseWhenNoBacktracer() {
        // given SDK without backtrace support
        XCTAssertNil(Embrace.client, "Test requires clean state - run this test class first")

        // when checking availability
        let available = EmbraceBacktrace.isAvailable

        // then backtrace is not available
        XCTAssertFalse(available, "Backtrace should not be available without backtracer")
    }
}

// MARK: - Main Test Suite

final class EmbraceBacktraceTests: XCTestCase {

    // MARK: - Basic Capture Tests

    @MainActor
    func test_backtrace_capturesCurrentThread() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing backtrace of current thread
        let backtrace = EmbraceBacktrace.backtrace()

        // then backtrace is captured
        XCTAssertEqual(backtrace.threads.count, 1, "Should capture exactly one thread")
        XCTAssertEqual(backtrace.threads.first?.index, 0, "Thread index should be 0")
        XCTAssertEqual(backtrace.timestampUnits, .nanoseconds, "Should use nanoseconds")
        XCTAssertGreaterThan(backtrace.timestamp, 0, "Timestamp should be non-zero")
    }

    @MainActor
    func test_backtrace_capturesNonEmptyCallStack() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing backtrace
        let backtrace = EmbraceBacktrace.backtrace()

        // then call stack has frames
        let frames = backtrace.threads.first?.frames(symbolicated: false) ?? []
        XCTAssertGreaterThan(frames.count, 0, "Should capture at least one frame")

        // then each frame has a valid address
        for frame in frames {
            XCTAssertGreaterThan(frame.address, 0, "Frame address should be non-zero")
        }
    }

    @MainActor
    func test_backtrace_timestampIsMonotonic() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing multiple backtraces
        let backtrace1 = EmbraceBacktrace.backtrace()
        Thread.sleep(forTimeInterval: 0.001)  // 1ms
        let backtrace2 = EmbraceBacktrace.backtrace()

        // then timestamps increase monotonically
        XCTAssertLessThan(backtrace1.timestamp, backtrace2.timestamp, "Timestamps should increase")
    }

    // MARK: - Frame Tests

    @MainActor
    func test_backtrace_unsymbolicatedFramesHaveNoSymbols() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing backtrace without symbolication
        let backtrace = EmbraceBacktrace.backtrace()
        let frames = backtrace.threads.first?.frames(symbolicated: false) ?? []

        // then frames have no symbol information
        for frame in frames {
            XCTAssertNil(frame.symbol, "Unsymbolicated frames should have no symbol")
            XCTAssertNil(frame.image, "Unsymbolicated frames should have no image")
        }
    }

    @MainActor
    func test_backtrace_symbolicatedFramesHaveSymbols() throws {
        // given SDK with backtrace support and symbolication
        try setUpEmbraceWithBacktraceSupport()

        // when capturing backtrace with symbolication
        let backtrace = EmbraceBacktrace.backtrace()
        let frames = backtrace.threads.first?.frames(symbolicated: true) ?? []

        // then at least some frames should be symbolicated
        let symbolicatedFrames = frames.filter { $0.symbol != nil }
        XCTAssertGreaterThan(symbolicatedFrames.count, 0, "Should have at least one symbolicated frame")

        // then symbolicated frames have valid data
        for frame in symbolicatedFrames {
            XCTAssertNotNil(frame.symbol, "Should have symbol")
            XCTAssertGreaterThan(frame.symbol!.address, 0, "Symbol address should be non-zero")
            XCTAssertFalse(frame.symbol!.name.isEmpty, "Symbol name should not be empty")
        }
    }

    @MainActor
    func test_backtrace_symbolicatedFramesHaveImageInfo() throws {
        // given SDK with backtrace support and symbolication
        try setUpEmbraceWithBacktraceSupport()

        // when capturing backtrace with symbolication
        let backtrace = EmbraceBacktrace.backtrace()
        let frames = backtrace.threads.first?.frames(symbolicated: true) ?? []

        // then at least some frames should have image info
        let framesWithImages = frames.filter { $0.image != nil }
        XCTAssertGreaterThan(framesWithImages.count, 0, "Should have at least one frame with image info")

        // then image info is valid
        for frame in framesWithImages {
            let image = frame.image!
            XCTAssertFalse(image.uuid.isEmpty, "Image UUID should not be empty")
            XCTAssertFalse(image.name.isEmpty, "Image name should not be empty")
            XCTAssertGreaterThan(image.address, 0, "Image address should be non-zero")
            XCTAssertGreaterThan(image.size, 0, "Image size should be non-zero")
        }
    }

    // MARK: - Availability Tests

    @MainActor
    func test_backtrace_isAvailable_returnsTrueWhenBacktracerProvided() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when checking availability
        let available = EmbraceBacktrace.isAvailable

        // then backtrace is available
        XCTAssertTrue(available, "Backtrace should be available with backtracer")
    }

    // MARK: - Codable Tests

    @MainActor
    func test_backtrace_isEncodable() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing and encoding backtrace
        let backtrace = EmbraceBacktrace.backtrace()
        let encoder = JSONEncoder()

        // then encoding succeeds
        XCTAssertNoThrow(try encoder.encode(backtrace), "Backtrace should be encodable")
    }

    @MainActor
    func test_backtrace_isDecodable() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing, encoding, and decoding backtrace
        let originalBacktrace = EmbraceBacktrace.backtrace()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(originalBacktrace)
        let decodedBacktrace = try decoder.decode(EmbraceBacktrace.self, from: data)

        // then decoded backtrace matches original
        XCTAssertEqual(decodedBacktrace.timestamp, originalBacktrace.timestamp)
        XCTAssertEqual(decodedBacktrace.timestampUnits, originalBacktrace.timestampUnits)
        XCTAssertEqual(decodedBacktrace.threads.count, originalBacktrace.threads.count)
        XCTAssertEqual(decodedBacktrace.threads.first?.index, originalBacktrace.threads.first?.index)
    }

    @MainActor
    func test_backtrace_symbolicatedFramesPreserveDataAfterEncodeDecode() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing symbolicated backtrace and encoding/decoding
        let originalBacktrace = EmbraceBacktrace.backtrace()
        let originalFrames = originalBacktrace.threads.first?.frames(symbolicated: true) ?? []

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(originalBacktrace)
        let decodedBacktrace = try decoder.decode(EmbraceBacktrace.self, from: data)
        let decodedFrames = decodedBacktrace.threads.first?.frames(symbolicated: true) ?? []

        // then frame data is preserved
        XCTAssertEqual(decodedFrames.count, originalFrames.count)

        for (original, decoded) in zip(originalFrames, decodedFrames) {
            XCTAssertEqual(decoded.address, original.address)
            XCTAssertEqual(decoded.symbol?.name, original.symbol?.name)
            XCTAssertEqual(decoded.symbol?.address, original.symbol?.address)
            XCTAssertEqual(decoded.image?.uuid, original.image?.uuid)
            XCTAssertEqual(decoded.image?.name, original.image?.name)
        }
    }

    // MARK: - Thread Safety Tests

    @MainActor
    func test_backtrace_captureFromMultipleThreadsSimultaneously() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when capturing backtraces from multiple threads
        let iterations = 10
        let expectation = self.expectation(description: "concurrent captures")
        expectation.expectedFulfillmentCount = iterations

        var backtraces: [EmbraceBacktrace] = []
        let backtracesLock = NSLock()

        for _ in 0..<iterations {
            DispatchQueue.global().async {
                let backtrace = EmbraceBacktrace.backtrace()
                backtracesLock.lock()
                backtraces.append(backtrace)
                backtracesLock.unlock()
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // then all captures succeed
        XCTAssertEqual(backtraces.count, iterations)
        for backtrace in backtraces {
            XCTAssertEqual(backtrace.threads.count, 1)
            let frames = backtrace.threads.first?.frames(symbolicated: false) ?? []
            XCTAssertGreaterThan(frames.count, 0)
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func test_backtrace_capturePerformance() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // when measuring capture performance
        measure {
            _ = EmbraceBacktrace.backtrace()
        }
    }

    @MainActor
    func test_backtrace_symbolicationPerformance() throws {
        // given SDK with backtrace support
        try setUpEmbraceWithBacktraceSupport()

        // given a captured backtrace
        let backtrace = EmbraceBacktrace.backtrace()

        // when measuring symbolication performance
        measure {
            _ = backtrace.threads.first?.frames(symbolicated: true)
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func setUpEmbraceWithBacktraceSupport() throws {
        guard Embrace.client == nil else {
            return  // Already set up
        }

        #if canImport(EmbraceKSCrashBacktraceSupport)
            let backtracer = KSCrashBacktracing()

            let options = Embrace.Options(
                appId: "BTRAC",
                captureServices: [],
                crashReporter: nil,
                backtracer: backtracer,
                symbolicator: backtracer
            )

            try Embrace.setup(options: options)
            try Embrace.client?.start()
        #else
            throw XCTSkip("EmbraceKSCrashBacktraceSupport not available")
        #endif
    }
}
