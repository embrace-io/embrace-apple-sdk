//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import OpenTelemetryApi
import TestSupport
import XCTest

@testable import EmbraceOTelInternal
@testable import OpenTelemetrySdk

/// Covers the calls that could block their caller on `processorQueue`: `forceFlush`, `shutdown` and the span flush.
///
/// A regression in these turns into a hang, so every call that could hang runs on a background queue
/// and is awaited with a bounded wait. A broken build then fails the test instead of stalling the suite.
final class EmbraceSpanProcessorBlockingTests: XCTestCase {

    var processor: EmbraceSpanProcessor!
    var childProcessor: FlushCountingSpanProcessor!
    var exporter: InMemorySpanExporter!
    var sdkStateProvider: MockEmbraceSDKStateProvider!
    var criticalResourceGroup: DispatchGroup!

    override func setUpWithError() throws {
        childProcessor = FlushCountingSpanProcessor()
        exporter = InMemorySpanExporter()
        sdkStateProvider = MockEmbraceSDKStateProvider()
        criticalResourceGroup = DispatchGroup()
    }

    override func tearDownWithError() throws {
        // Leave the group if a test kept it closed, so no queued block stays parked after the test.
        if criticalResourceGroup.wait(timeout: .now()) == .timedOut {
            criticalResourceGroup.leave()
        }
    }

    // MARK: - Critical resource group closed

    func test_forceFlush_whenCriticalResourceGroupIsClosed_doesNotBlock() throws {
        // given a processor whose queue is parked on a closed critical resource group
        givenProcessor(withClosedGroup: true)
        let span = startSpan()

        // when flushing
        XCTAssertTrue(completesInTime { self.processor.forceFlush(timeout: nil) })

        // then nothing ran yet
        XCTAssertEqual(childProcessor.flushCount, 0)

        // and it runs once the group is left
        criticalResourceGroup.leave()
        drainProcessorQueue()
        XCTAssertEqual(childProcessor.flushCount, 1)
        XCTAssertNotNil(childProcessor.startedSpans[span.context.spanId])
    }

    func test_shutdown_whenCriticalResourceGroupIsClosed_doesNotBlock() throws {
        // given a processor whose queue is parked on a closed critical resource group
        givenProcessor(withClosedGroup: true)
        _ = startSpan()

        // when shutting down
        XCTAssertTrue(completesInTime { self.processor.shutdown(explicitTimeout: nil) })

        // then nothing ran yet
        XCTAssertFalse(childProcessor.isShutdown)
        XCTAssertFalse(exporter.isShutdown)

        // and it runs once the group is left
        criticalResourceGroup.leave()
        drainProcessorQueue()
        XCTAssertTrue(childProcessor.isShutdown)
        XCTAssertTrue(exporter.isShutdown)
    }

    func test_flushSpan_whenCriticalResourceGroupIsClosed_doesNotBlock() throws {
        // given a processor whose queue is parked on a closed critical resource group
        givenProcessor(withClosedGroup: true)
        let span = startSpan()
        markForFlush(span)

        // when flushing a span
        XCTAssertTrue(completesInTime { self.processor.flush(span: span) })

        // then the flushed snapshot is exported once the group is left
        criticalResourceGroup.leave()
        drainProcessorQueue()
        XCTAssertTrue(exportedFlushedSnapshot(of: span))
    }

    // MARK: - Called from processorQueue

    func test_forceFlush_fromChildProcessorCallback_runsInline() throws {
        // given a child processor that flushes from its own onEnd callback
        givenProcessor()
        var flushCountAfterReentrantFlush: Int?
        childProcessor.onEndHandler = { [unowned self] in
            processor.forceFlush(timeout: nil)
            flushCountAfterReentrantFlush = childProcessor.flushCount
        }

        // when a span ends
        startSpan().end()
        drainProcessorQueue()

        // then the flush ran inline instead of trapping
        XCTAssertEqual(flushCountAfterReentrantFlush, 1)
    }

    func test_shutdown_fromChildProcessorCallback_runsInline() throws {
        // given a child processor that shuts down from its own onStart callback
        givenProcessor()
        var isShutdownAfterReentrantShutdown: Bool?
        childProcessor.onStartHandler = { [unowned self] in
            processor.shutdown(explicitTimeout: nil)
            isShutdownAfterReentrantShutdown = childProcessor.isShutdown
        }

        // when a span starts
        _ = startSpan()
        drainProcessorQueue()

        // then the shutdown ran inline instead of trapping
        XCTAssertEqual(isShutdownAfterReentrantShutdown, true)
        XCTAssertTrue(exporter.isShutdown)
    }

    func test_flushSpan_fromProcessorQueue_doesNotTrap() throws {
        // given a span
        givenProcessor()
        let span = startSpan()
        drainProcessorQueue()
        markForFlush(span)

        // when it's flushed from processorQueue
        processor.processorQueue.async { [unowned self] in
            processor.flush(span: span)
        }

        // then the export is queued and runs once the current block finishes
        // (drained twice: once for the outer block, once for the export it queued)
        drainProcessorQueue()
        drainProcessorQueue()
        XCTAssertTrue(exportedFlushedSnapshot(of: span))
    }

    // MARK: - Timeout

    func test_forceFlush_honorsTimeout() throws {
        // given a child processor whose flush is blocked
        givenProcessor()
        let release = DispatchSemaphore(value: 0)
        childProcessor.onFlushHandler = { release.wait() }

        // when flushing with a short timeout
        // then the caller is released while the child processor is still blocked
        XCTAssertTrue(completesInTime { self.processor.forceFlush(timeout: 0.1) })
        XCTAssertEqual(childProcessor.flushCount, 0)

        // and the flush still finishes later
        release.signal()
        drainProcessorQueue()
        XCTAssertEqual(childProcessor.flushCount, 1)
    }

    func test_shutdown_honorsTimeout() throws {
        // given a child processor whose shutdown is blocked
        givenProcessor()
        let release = DispatchSemaphore(value: 0)
        childProcessor.onShutdownHandler = { release.wait() }

        // when shutting down with a short timeout
        // then the caller is released while the child processor is still blocked
        XCTAssertTrue(completesInTime { self.processor.shutdown(explicitTimeout: 0.1) })
        XCTAssertFalse(exporter.isShutdown)

        // and the shutdown still finishes later
        release.signal()
        drainProcessorQueue()
        XCTAssertTrue(childProcessor.isShutdown)
        XCTAssertTrue(exporter.isShutdown)
    }

    // MARK: - Critical resource group open

    func test_flushSpan_whenChildProcessorIsBlocked_doesNotBlock() throws {
        // given a started processor whose child processor is stuck in onStart
        givenProcessor()
        let release = DispatchSemaphore(value: 0)
        childProcessor.onStartHandler = { release.wait() }
        let span = startSpan()
        markForFlush(span)

        // when flushing the span
        // then the caller isn't held behind the stuck callback
        XCTAssertTrue(completesInTime { self.processor.flush(span: span) })

        // and the flushed snapshot is exported once the callback returns
        release.signal()
        drainProcessorQueue()
        XCTAssertTrue(exportedFlushedSnapshot(of: span))
    }

    func test_flushSpan_whenCriticalResourceGroupIsOpen_exportsCurrentSnapshot() throws {
        // given a started processor and a span whose start was already exported
        givenProcessor(withClosedGroup: true)
        criticalResourceGroup.leave()
        let span = startSpan()
        drainProcessorQueue()
        XCTAssertFalse(exportedFlushedSnapshot(of: span))

        // when the span changes and is flushed
        markForFlush(span)
        XCTAssertTrue(completesInTime { self.processor.flush(span: span) })

        // then the flushed snapshot is exported
        drainProcessorQueue()
        XCTAssertTrue(exportedFlushedSnapshot(of: span))
    }

    func test_forceFlush_whenCriticalResourceGroupIsOpen_waitsForQueuedWork() throws {
        // given a processor with an open critical resource group and started spans
        givenProcessor(withClosedGroup: true)
        criticalResourceGroup.leave()
        let spans = (0..<50).map { _ in startSpan() }

        // when flushing
        processor.forceFlush(timeout: nil)

        // then every span queued before the flush reached the child processor
        XCTAssertEqual(childProcessor.flushCount, 1)
        XCTAssertEqual(childProcessor.startedSpans.count, spans.count)
    }
}

extension EmbraceSpanProcessorBlockingTests {
    fileprivate func givenProcessor(withClosedGroup: Bool = false) {
        if withClosedGroup {
            criticalResourceGroup.enter()
        }

        processor = EmbraceSpanProcessor(
            spanProcessors: [childProcessor],
            spanExporters: [exporter],
            sdkStateProvider: sdkStateProvider,
            criticalResourceGroup: withClosedGroup ? criticalResourceGroup : nil
        )
    }

    fileprivate func startSpan() -> ReadableSpan {
        SpanSdk.startSpan(
            context: .create(traceId: .random(), spanId: .random(), traceFlags: .init(), traceState: .init()),
            name: "example",
            instrumentationScopeInfo: .init(),
            kind: .client,
            parentContext: nil,
            hasRemoteParent: false,
            spanLimits: .init(),
            spanProcessor: processor,
            clock: MillisClock(),
            resource: Resource(),
            attributes: .init(capacity: 10),
            links: [],
            totalRecordedLinks: 0,
            startTime: Date()
        )
    }

    /// Sets an attribute that the span's start export doesn't carry, so only an export of a later snapshot, like the one `flush(span:)` takes, has it.
    fileprivate func markForFlush(_ span: ReadableSpan) {
        span.setAttribute(key: Self.flushMarkerKey, value: true)
    }

    /// Whether the exporter received a snapshot of `span` taken after `markForFlush(_:)`.
    fileprivate func exportedFlushedSnapshot(of span: ReadableSpan) -> Bool {
        exporter.exportedSpans[span.context.spanId]?.attributes[Self.flushMarkerKey] == .bool(true)
    }

    fileprivate static let flushMarkerKey = "test.flushed"

    /// Blocks until every block already queued on the processor queue has run.
    fileprivate func drainProcessorQueue() {
        processor.processorQueue.sync {}
    }

    /// Runs `work` on a background queue and returns whether it finished within `timeout`.
    fileprivate func completesInTime(timeout: TimeInterval = 2, _ work: @escaping () -> Void) -> Bool {
        let group = DispatchGroup()
        DispatchQueue.global(qos: .userInitiated).async(group: group, execute: work)
        return group.wait(timeout: .now() + timeout) == .success
    }
}

/// Span processor that records what reached it and lets tests hook into each callback.
final class FlushCountingSpanProcessor: SpanProcessor {
    let isStartRequired = true
    let isEndRequired = true

    var onStartHandler: (() -> Void)?
    var onEndHandler: (() -> Void)?
    var onFlushHandler: (() -> Void)?
    var onShutdownHandler: (() -> Void)?

    private let state = EmbraceMutex<(startedSpans: [SpanId: SpanData], flushCount: Int, isShutdown: Bool)>(([:], 0, false))

    var startedSpans: [SpanId: SpanData] { state.withLock { $0.startedSpans } }
    var flushCount: Int { state.withLock { $0.flushCount } }
    var isShutdown: Bool { state.withLock { $0.isShutdown } }

    func onStart(parentContext: SpanContext?, span: ReadableSpan) {
        let data = span.toSpanData()
        state.withLock { $0.startedSpans[data.spanId] = data }
        onStartHandler?()
    }

    func onEnd(span: ReadableSpan) {
        onEndHandler?()
    }

    func forceFlush(timeout: TimeInterval?) {
        onFlushHandler?()
        state.withLock { $0.flushCount += 1 }
    }

    func shutdown(explicitTimeout: TimeInterval?) {
        onShutdownHandler?()
        state.withLock { $0.isShutdown = true }
    }
}
