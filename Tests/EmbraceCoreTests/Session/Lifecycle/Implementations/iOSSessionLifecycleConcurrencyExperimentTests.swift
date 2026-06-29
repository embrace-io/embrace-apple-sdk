//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//
//  EXPERIMENT — not for merge.
//
//  `test_startSession_fromNonMainThread` flakes in CI with a 5s expectation timeout. Two fixes
//  (.background -> .default QoS) failed to hold. Hypothesis: it's GCD global-pool starvation, not
//  QoS priority — under suite load every global worker thread is busy/blocked, so a newly dispatched
//  block can't get a thread and the expectation never fulfils in time.
//
//  This file reproduces that deterministically: setUp saturates the .default global concurrent pool
//  with blocked workers, then each variation dispatches the same off-main `startSession` work a
//  different way. The control (.default global) should fail; an approach that doesn't depend on the
//  shared GCD pool (e.g. a dedicated Thread) should pass. We stress these in CI to pick a winner,
//  then ship only that one under a real ticket and delete this file.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceCore

#if os(iOS) || os(tvOS)

    final class iOSSessionLifecycleConcurrencyExperimentTests: XCTestCase {

        var mockController = MockSessionController()
        var lifecycle: iOSSessionLifecycle!

        private let saturationRelease = DispatchSemaphore(value: 0)
        private var saturationCount = 0

        // Short on purpose: a robust approach runs in milliseconds, so 2s cleanly separates
        // "ran" from "starved". (Production uses .longTimeout = 5s.)
        private let timeout: TimeInterval = 2.0

        override func setUpWithError() throws {
            lifecycle = iOSSessionLifecycle(controller: mockController)
            lifecycle.setup()
            // Saturation is opt-in so the same variations can run two ways:
            //   EXPERIMENT_SATURATE set   → deterministic pool-exhaustion (mechanism arm)
            //   EXPERIMENT_SATURATE unset → isolation/real-suite (do they pass under normal load?)
            if ProcessInfo.processInfo.environment["EXPERIMENT_SATURATE"] != nil {
                saturateGlobalPool()
            }
        }

        override func tearDownWithError() throws {
            releaseGlobalPool()
            lifecycle = nil
        }

        /// Flood the `.default` global concurrent queue with blocked workers so a freshly dispatched
        /// `.default` block can't obtain a thread — the starvation we believe CI hits under load.
        private func saturateGlobalPool() {
            let count = 256
            for _ in 0..<count {
                DispatchQueue.global(qos: .default).async { [saturationRelease] in
                    saturationRelease.wait()
                }
            }
            saturationCount = count
            // Let GCD actually occupy its worker threads before the test dispatches its block.
            Thread.sleep(forTimeInterval: 0.25)
        }

        private func releaseGlobalPool() {
            for _ in 0..<saturationCount {
                saturationRelease.signal()
            }
            saturationCount = 0
        }

        private func verify(_ expectation: XCTestExpectation) {
            wait(for: [expectation], timeout: timeout)
            XCTAssertTrue(mockController.didCallStartSession)
            XCTAssertEqual(mockController.currentSession?.state, "foreground")
        }

        // MARK: - Variations

        /// V0 — control: the current shipping approach. Expected to FAIL under saturation.
        func test_v0_control_defaultGlobal() {
            let expectation = XCTestExpectation(description: "v0")
            DispatchQueue.global(qos: .default).async { [self] in
                lifecycle.startSession()
                expectation.fulfill()
            }
            verify(expectation)
        }

        /// V1 — dedicated OS thread (not the GCD pool). Expected to PASS.
        func test_v1_detachNewThread() {
            let expectation = XCTestExpectation(description: "v1")
            Thread.detachNewThread { [self] in
                lifecycle.startSession()
                expectation.fulfill()
            }
            verify(expectation)
        }

        /// V2 — a dedicated (non-global) serial DispatchQueue. Still draws from the GCD pool, so this
        /// tells us whether a private queue is enough or whether the pool itself is the problem.
        func test_v2_dedicatedQueue() {
            let queue = DispatchQueue(label: "experiment.nonmain")
            let expectation = XCTestExpectation(description: "v2")
            queue.async { [self] in
                lifecycle.startSession()
                expectation.fulfill()
            }
            verify(expectation)
        }

        /// V3 — higher QoS global. If priority were the issue this would pass; if it's pool
        /// exhaustion it should fail like V0.
        func test_v3_userInitiatedGlobal() {
            let expectation = XCTestExpectation(description: "v3")
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                lifecycle.startSession()
                expectation.fulfill()
            }
            verify(expectation)
        }
    }

#endif
