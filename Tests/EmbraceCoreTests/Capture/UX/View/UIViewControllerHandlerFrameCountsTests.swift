//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import EmbraceSemantics
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    /// Smoothness frame counts on `emb-screen-view`: each screen gets the difference of the running
    /// totals between its appear and its end.
    final class UIViewControllerHandlerFrameCountsTests: XCTestCase {

        private var dataSource: MockUIViewControllerHandlerDataSource!
        private var handler: UIViewControllerHandler!
        /// What the handler reads as the smoothness totals; `nil` while smoothness isn't running.
        private var totals: SmoothnessFrameCounts? = SmoothnessFrameCounts()

        private var otel: MockOTelSignalsHandler {
            dataSource.otel as! MockOTelSignalsHandler
        }

        override func setUpWithError() throws {
            try super.setUpWithError()
            totals = SmoothnessFrameCounts()
            dataSource = MockUIViewControllerHandlerDataSource()
            dataSource.instrumentFirstRender = false
            // Runs the handler's work inline so every call has finished by the time it returns.
            handler = UIViewControllerHandler(queue: MockQueue(), frameCountTotals: { [unowned self] in self.totals })
            handler.dataSource = dataSource
        }

        override func tearDownWithError() throws {
            handler = nil
            dataSource = nil
            try super.tearDownWithError()
        }

        // MARK: - Helpers

        private var screenSpans: [EmbraceSpan] {
            otel.startedSpans.filter { $0.name == SpanSemantics.View.screenName }
        }

        /// Adds `dropped` dropped frames and `ticks` ticks to the running totals.
        private func advance(dropped: Int, ticks: Int) {
            totals?.droppedFrames += dropped
            totals?.expectedFrames += ticks + dropped
        }

        private func counts(of span: EmbraceSpan?) -> (dropped: Int?, expected: Int?) {
            (
                span?.attributes[SpanSemantics.Smoothness.keyDroppedFrames] as? Int,
                span?.attributes[SpanSemantics.Smoothness.keyExpectedFrames] as? Int
            )
        }

        // MARK: - Tests

        func test_screen_getsFramesBetweenAppearAndDisappear() throws {
            advance(dropped: 7, ticks: 100)
            let vc = MockViewController()

            handler.onViewDidAppearEnd(vc)
            advance(dropped: 2, ticks: 10)
            handler.onViewDidDisappear(vc)

            let span = try XCTUnwrap(screenSpans.first)
            XCTAssertNotNil(span.endTime)
            XCTAssertEqual(counts(of: span).dropped, 2)
            XCTAssertEqual(counts(of: span).expected, 12)
        }

        func test_screen_withNoFrames_getsZeros() throws {
            let vc = MockViewController()

            handler.onViewDidAppearEnd(vc)
            handler.onViewDidDisappear(vc)

            let span = try XCTUnwrap(screenSpans.first)
            XCTAssertEqual(counts(of: span).dropped, 0)
            XCTAssertEqual(counts(of: span).expected, 0)
        }

        func test_nestedScreens_eachGetTheirOwnWindow() throws {
            let container = MockViewController()
            let child = MockViewController()

            handler.onViewDidAppearEnd(container)
            advance(dropped: 1, ticks: 5)
            handler.onViewDidAppearEnd(child)
            advance(dropped: 3, ticks: 5)
            handler.onViewDidDisappear(child)
            handler.onViewDidDisappear(container)

            XCTAssertEqual(screenSpans.count, 2)
            XCTAssertEqual(counts(of: screenSpans[0]).dropped, 4)
            XCTAssertEqual(counts(of: screenSpans[1]).dropped, 3)
        }

        func test_disappearBeforeAppear_writesNothing() throws {
            let vc = MockViewController()
            vc.emb_instrumentation_state = ViewInstrumentationState(identifier: UUID().uuidString)

            // Synchronous push-then-pop: the disappear is processed first, with no screen to end.
            handler.onViewDidDisappear(vc)
            XCTAssertTrue(screenSpans.isEmpty)

            handler.onViewDidAppearEnd(vc)

            let span = try XCTUnwrap(screenSpans.first)
            XCTAssertNil(span.endTime)
            XCTAssertNil(counts(of: span).dropped)
        }

        func test_reusedController_eachAppearanceStartsFresh() throws {
            let vc = MockViewController()

            handler.onViewDidAppearEnd(vc)
            advance(dropped: 5, ticks: 5)
            handler.onViewDidDisappear(vc)

            advance(dropped: 9, ticks: 9)

            handler.onViewDidAppearEnd(vc)
            advance(dropped: 1, ticks: 1)
            handler.onViewDidDisappear(vc)

            XCTAssertEqual(screenSpans.count, 2)
            XCTAssertEqual(counts(of: screenSpans[0]).dropped, 5)
            XCTAssertEqual(counts(of: screenSpans[1]).dropped, 1)
        }

        func test_backgroundMidScreen_writesFramesUpToForegroundEnd() throws {
            let vc = MockViewController()

            handler.onViewDidAppearEnd(vc)
            advance(dropped: 2, ticks: 3)
            handler.foregroundSessionDidEnd()
            advance(dropped: 50, ticks: 50)
            handler.onViewDidDisappear(vc)

            let span = try XCTUnwrap(screenSpans.first)
            XCTAssertNotNil(span.endTime)
            XCTAssertEqual(counts(of: span).dropped, 2)
            XCTAssertEqual(counts(of: span).expected, 5)
        }

        func test_controllerGoneWithoutDisappear_isNotAttributedToAnotherScreen() throws {
            var gone: MockViewController? = MockViewController()
            handler.onViewDidAppearEnd(gone!)
            advance(dropped: 4, ticks: 4)
            gone = nil

            let next = MockViewController()
            handler.onViewDidAppearEnd(next)
            advance(dropped: 1, ticks: 1)
            handler.onViewDidDisappear(next)

            let nextSpan = try XCTUnwrap(screenSpans.last)
            XCTAssertEqual(counts(of: nextSpan).dropped, 1)
            XCTAssertEqual(counts(of: nextSpan).expected, 2)
        }

        func test_smoothnessNotRunningAtAppear_writesNothing() throws {
            totals = nil
            let vc = MockViewController()

            handler.onViewDidAppearEnd(vc)
            totals = SmoothnessFrameCounts()
            handler.onViewDidDisappear(vc)

            let span = try XCTUnwrap(screenSpans.first)
            XCTAssertNotNil(span.endTime)
            XCTAssertNil(counts(of: span).dropped)
            XCTAssertNil(counts(of: span).expected)
        }

        func test_smoothnessStoppedBeforeEnd_writesNothing() throws {
            let vc = MockViewController()

            handler.onViewDidAppearEnd(vc)
            totals = nil
            handler.onViewDidDisappear(vc)

            let span = try XCTUnwrap(screenSpans.first)
            XCTAssertNil(counts(of: span).dropped)
        }
    }

#endif
