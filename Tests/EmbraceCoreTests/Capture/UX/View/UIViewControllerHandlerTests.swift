//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import XCTest
    @testable import EmbraceCore
    import OpenTelemetryApi
    import EmbraceOTelInternal
    import TestSupport
    import EmbraceCommonInternal

    class UIViewControllerHandlerTests: XCTestCase {

        var dataSource: MockUIViewControllerHandlerDataSource!
        var otel: MockEmbraceOpenTelemetry {
            dataSource.otel as! MockEmbraceOpenTelemetry
        }
        var handler: UIViewControllerHandler!

        override func setUpWithError() throws {
            dataSource = MockUIViewControllerHandlerDataSource()
            handler = UIViewControllerHandler(queue: DispatchQueue.main)
            handler.dataSource = dataSource
        }

        func test_parentSpan_validId() {
            // given a handler
            // when it has a parentSpan for a view controller
            let id = "test"
            let span = createSpan()
            handler.parentSpans[id] = span

            // then it is succesfully fetched
            let vc = MockViewController()
            vc.emb_instrumentation_state = .init(identifier: id)

            let parent = handler.parentSpan(for: vc)
            XCTAssertEqual(span.name, parent!.name)
            XCTAssertEqual(span.context.spanId, parent!.context.spanId)
            XCTAssertEqual(span.context.traceId, parent!.context.traceId)
        }

        func test_parentSpan_invalidId() {
            // given a handler
            // when fetching the parent span for a view controller
            // that doesn't have one
            let vc = MockViewController()
            vc.emb_instrumentation_state = .init(identifier: "test")

            // then the result is nil
            let parent = handler.parentSpan(for: vc)
            XCTAssertNil(parent)
        }

        func test_foregroundSessionDidEnd_clearsCache() {
            // given a handler with cached spans
            let id = "test"
            let span = createSpan()
            handler.parentSpans[id] = span
            handler.viewDidLoadSpans[id] = span
            handler.viewWillAppearSpans[id] = span
            handler.viewDidAppearSpans[id] = span
            handler.visibilitySpans[id] = span
            handler.uiReadySpans[id] = span
            handler.alreadyFinishedUiReadyIds.insert(id)

            // when foregroundSessionDidEnd is called
            handler.foregroundSessionDidEnd()

            // then the cache is cleared
            wait {
                return self.cacheIsEmpty(true)
            }
        }

        func test_foregroundSessionDidEnd_endsSpans() {
            // given a handler with cached spans
            let id = "test"

            let parentSpan = createTTFRSpan()
            handler.parentSpans[id] = parentSpan

            let viewDidLoadSpan = createViewDidLoadSpan()
            handler.viewDidLoadSpans[id] = viewDidLoadSpan

            let viewWillAppearSpan = createViewWillAppearSpan()
            handler.viewWillAppearSpans[id] = viewWillAppearSpan

            let viewIsAppearing = createViewWillAppearSpan()
            handler.viewIsAppearingSpans[id] = viewIsAppearing

            let viewDidAppearSpan = createViewDidAppearSpan()
            handler.viewDidAppearSpans[id] = viewDidAppearSpan

            let visibilitySpan = createVisibilitySpan()
            handler.visibilitySpans[id] = visibilitySpan

            let uiReadySpan = createUiReadySpan()
            handler.uiReadySpans[id] = uiReadySpan

            // when appDidEnterBackground is called
            handler.foregroundSessionDidEnd()

            // then all spans are ended
            wait {
                return self.otel.spanProcessor.endedSpans.count == 7
            }
        }

        func test_onViewDidLoad_deactivatedService() {
            // given a handler that is not active
            dataSource.state = .paused

            // when view did load is called
            let vc = MockViewController()
            handler.onViewDidLoadStart(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_onViewDidLoad_instrumentationDisabled() {
            // given a handler with instrumentation disabled
            dataSource.instrumentFirstRender = false

            // when view did load is called
            let vc = MockViewController()
            handler.onViewDidLoadStart(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_onViewDidLoad_captureDisabled() {
            // given a handler
            // when view did load is called on a view controller with capture disabled
            let vc = MockViewController()
            vc.shouldCaptureViewInEmbrace = false
            handler.onViewDidLoadStart(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_onViewDidLoad_vcBlocked_byType() {
            // given a handler with a block list
            dataSource.blockList = ViewControllerBlockList(types: [MockViewController.self])

            // when view did load is called
            let vc = MockViewController()
            handler.onViewDidLoadStart(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_onViewDidLoad_vcBlocked_byName() {
            // given a handler with a block list
            dataSource.blockList = ViewControllerBlockList(names: ["Mock"])

            // when view did load is called
            let vc = MockViewController()
            handler.onViewDidLoadStart(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_onViewDidLoad_vcBlocked_hostingController() {
            // given a handler with a block list
            dataSource.blockList = ViewControllerBlockList(blockHostingControllers: true)

            // when view did load is called
            let vc = TestHostingSubclassController(rootView: TestView())
            handler.onViewDidLoadStart(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_onViewDidLoad_vcBlocked_hostingControllerChild() {
            // given a handler with a block list
            dataSource.blockList = ViewControllerBlockList(blockHostingControllers: true)

            // when view did load is called
            let parent = TestHostingSubclassController(rootView: TestView())
            let vc = MockViewController()
            parent.addChild(vc)
            handler.onViewDidLoadStart(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_onViewDidAppear_instrumentationDisabled() {
            // given a handler with instrumentation disabled
            dataSource.instrumentVisibility = false

            // when view did load is called
            let vc = MockViewController()
            handler.onViewDidAppearEnd(vc)

            // then no spans are created
            wait {
                return self.otel.spanProcessor.startedSpans.count == 0
            }
        }

        func test_timeToFirstRenderFlow() {
            // given a handler
            let vc = MockViewController()

            // when a view controller is loaded and shown
            let parentName = "time-to-first-render"
            validateViewDidLoadSpans(vc: vc, parentName: parentName)
            validateViewWillAppearSpans(vc: vc, parentName: parentName)
            validateViewIsAppearingSpans(vc: vc, parentName: parentName)
            validateViewDidAppearSpans(vc: vc, parentName: parentName)

            // then all the spans are created and ended at the right times
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.endedSpans.first(where: { $0.name.contains(parentName) })
                return parent != nil && self.cacheIsEmpty()
            }
        }

        func test_timeToFirstRenderFlow_interrupted() {
            // given a handler
            let vc = MockViewController()

            // when a view controller is loaded but somehow disappears
            // before appearing, then the active spans are ended
            let parentName = "time-to-first-render"
            validateViewDidLoadSpans(vc: vc, parentName: parentName)
            validateViewWillAppearSpans(vc: vc, parentName: parentName)

            handler.onViewDidDisappear(vc)

            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.endedSpans.first(where: { $0.name.contains(parentName) })
                return parent != nil && parent!.status.isError == true && self.cacheIsEmpty()
            }
        }

        func test_timeToFirstRenderFlow_interrupted_background() {
            // given a handler
            let vc = MockViewController()

            // when a view controller is loaded but somehow disappears
            // before appearing, then the active spans are ended
            let parentName = "time-to-first-render"
            validateViewDidLoadSpans(vc: vc, parentName: parentName)
            validateViewWillAppearSpans(vc: vc, parentName: parentName)

            handler.foregroundSessionDidEnd()

            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.endedSpans.first(where: { $0.name.contains(parentName) })
                return parent != nil && parent!.status.isError == true && self.cacheIsEmpty()
            }
        }

        func test_timeToInteractiveFlow() throws {
            // given a handler
            let vc = MockInteractableViewController()

            // when a view controller is loaded and shown
            // then all the spans are created and ended at the right times
            let parentName = "time-to-interactive"
            validateViewDidLoadSpans(vc: vc, parentName: parentName)
            validateViewWillAppearSpans(vc: vc, parentName: parentName)
            validateViewIsAppearingSpans(vc: vc, parentName: parentName)
            validateViewDidAppearSpans(vc: vc, parentName: parentName)

            // when view did appear ends
            // then the ui ready span should start
            wait {
                let parent = self.otel.spanProcessor.startedSpans.first(where: { $0.name.contains(parentName) })
                let child = self.otel.spanProcessor.startedSpans.first(where: { $0.name == "ui-ready" })

                return child != nil && child!.parentSpanId == parent!.spanId
            }

            // when the view controller becomes interactable
            handler.onViewBecameInteractive(vc)

            // then the spans are ended
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.endedSpans.first(where: { $0.name.contains(parentName) })
                let uiReady = self.otel.spanProcessor.endedSpans.first(where: { $0.name == "ui-ready" })

                return parent != nil && uiReady != nil && parent!.endTime == uiReady!.endTime && self.cacheIsEmpty()
            }
        }

        func test_timeToInteractiveFlow_earlyInteraction() throws {
            // given a handler
            let vc = MockInteractableViewController()

            // when a view controller is loaded and flagged as interactive
            // before it appears, then all spans are created correctly
            // and the parent span and ui-ready span are ended as soon as viewDidAppear ends
            let parentName = "time-to-interactive"
            validateViewDidLoadSpans(vc: vc, parentName: parentName)
            handler.onViewBecameInteractive(vc)
            validateViewWillAppearSpans(vc: vc, parentName: parentName)
            validateViewIsAppearingSpans(vc: vc, parentName: parentName)
            validateViewDidAppearSpans(vc: vc, parentName: parentName)

            // then the spans are ended
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.endedSpans.first(where: { $0.name.contains(parentName) })
                let uiReady = self.otel.spanProcessor.endedSpans.first(where: { $0.name == "ui-ready" })

                return parent != nil && uiReady != nil && parent!.endTime == uiReady!.endTime && self.cacheIsEmpty()
            }
        }

        func test_timeToInteractiveFlow_interrupted() throws {
            // given a handler
            let vc = MockInteractableViewController()

            // when a view controller is loaded but somehow disappears
            // before appearing, then the active spans are ended
            let parentName = "time-to-interactive"
            validateViewDidLoadSpans(vc: vc, parentName: parentName)
            validateViewWillAppearSpans(vc: vc, parentName: parentName)
            handler.onViewDidDisappear(vc)

            // then the spans are ended
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.endedSpans.first(where: { $0.name.contains(parentName) })
                return parent != nil && parent!.status.isError == true && self.cacheIsEmpty()
            }
        }

        func test_timeToInteractiveFlow_interrupted_background() throws {
            // given a handler
            let vc = MockInteractableViewController()

            // when a view controller is loaded but somehow disappears
            // before appearing, then the active spans are ended
            let parentName = "time-to-interactive"
            validateViewDidLoadSpans(vc: vc, parentName: parentName)
            validateViewWillAppearSpans(vc: vc, parentName: parentName)

            handler.foregroundSessionDidEnd()

            // then the spans are ended
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.endedSpans.first(where: { $0.name.contains(parentName) })
                return parent != nil && parent!.status.isError == true && self.cacheIsEmpty()
            }
        }

        func validateViewDidLoadSpans(vc: UIViewController, parentName: String) {
            // when view did load starts
            handler.onViewDidLoadStart(vc)

            // then spans are created
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.startedSpans.first(where: { $0.name.contains(parentName) })
                let child = self.otel.spanProcessor.startedSpans.first(where: { $0.name == "emb-view-did-load" })

                return parent != nil && child!.parentSpanId == parent!.spanId && child!.embType == .viewLoad
            }

            // when view did load ends
            handler.onViewDidLoadEnd(vc)

            // then the view did load span is ended
            wait(timeout: .longTimeout) {
                let span = self.otel.spanProcessor.startedSpans.first(where: { $0.name == "emb-view-did-load" })
                return span != nil && self.handler.viewDidLoadSpans.isEmpty
            }
        }

        func validateViewWillAppearSpans(vc: UIViewController, parentName: String) {
            // when view will appear starts
            handler.onViewWillAppearStart(vc)

            // then a child span is created
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.startedSpans.first(where: { $0.name.contains(parentName) })
                let child = self.otel.spanProcessor.startedSpans.first(where: { $0.name == "emb-view-will-appear" })

                return parent != nil && child!.parentSpanId == parent!.spanId && child!.embType == .viewLoad
            }

            // when view will appear ends
            handler.onViewWillAppearEnd(vc)

            // then the view will appear span is ended
            wait(timeout: .longTimeout) {
                let span = self.otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-view-will-appear" })
                return span != nil && self.handler.viewWillAppearSpans.isEmpty
            }
        }

        func validateViewIsAppearingSpans(vc: UIViewController, parentName: String) {
            // when view is appearing starts
            handler.onViewIsAppearingStart(vc)

            // then a child span is created
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.startedSpans.first(where: { $0.name.contains(parentName) })
                let child = self.otel.spanProcessor.startedSpans.first(where: { $0.name == "emb-view-is-appearing" })

                return parent != nil && child!.parentSpanId == parent!.spanId && child!.embType == .viewLoad
            }

            // when view is appearing ends
            handler.onViewIsAppearingEnd(vc)

            // then the view will appear span is ended
            wait(timeout: .longTimeout) {
                let span = self.otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-view-is-appearing" })
                return span != nil && self.handler.viewIsAppearingSpans.isEmpty
            }
        }

        func validateViewDidAppearSpans(vc: UIViewController, parentName: String) {
            // when view did appear starts
            handler.onViewDidAppearStart(vc)

            // then a child span is created
            wait(timeout: .longTimeout) {
                let parent = self.otel.spanProcessor.startedSpans.first(where: { $0.name.contains(parentName) })
                let child = self.otel.spanProcessor.startedSpans.first(where: { $0.name == "emb-view-did-appear" })

                return parent != nil && child!.parentSpanId == parent!.spanId && child!.embType == .viewLoad
            }

            // when view did appear ends
            handler.onViewDidAppearEnd(vc)

            // then the view did appear span is ended
            wait(timeout: .longTimeout) {
                let span1 = self.otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-view-did-appear" })
                let span2 = self.otel.spanProcessor.startedSpans.first(where: { $0.name == "emb-screen-view" })

                return span1 != nil && span1!.embType == .viewLoad && span2 != nil && span2!.embType == .view
                    && self.handler.viewDidAppearSpans.isEmpty
            }
        }

        func cacheIsEmpty(_ checkVisibilitySpans: Bool = false) -> Bool {
            return handler.parentSpans.count == 0 && handler.viewDidLoadSpans.count == 0
                && handler.viewWillAppearSpans.count == 0 && handler.viewIsAppearingSpans.count == 0
                && handler.viewDidAppearSpans.count == 0
                && (!checkVisibilitySpans || handler.visibilitySpans.count == 0) && handler.uiReadySpans.count == 0
                && handler.alreadyFinishedUiReadyIds.count == 0
        }
    }

    extension UIViewControllerHandlerTests {
        func createSpan(name: String? = nil, parent: Span? = nil) -> Span {
            let builder = otel.buildSpan(name: name ?? "test-span", type: .viewLoad, attributes: [:])

            if let parent = parent {
                builder.setParent(parent)
            }

            return builder.startSpan()
        }

        func createTTFRSpan() -> Span {
            return createSpan(name: "time-to-first-render")
        }

        func createTTISpan() -> Span {
            return createSpan(name: "time-to-interactive")
        }

        func createViewDidLoadSpan() -> Span {
            return createSpan(name: "view-did-load")
        }

        func createViewWillAppearSpan() -> Span {
            return createSpan(name: "view-will-appear")
        }

        func createViewIsAppearingSpan() -> Span {
            return createSpan(name: "view-is-appearing")
        }

        func createViewDidAppearSpan() -> Span {
            return createSpan(name: "view-did-appear")
        }

        func createVisibilitySpan() -> Span {
            return createSpan(name: "emb-screen-view")
        }

        func createUiReadySpan() -> Span {
            return createSpan(name: "ui-ready")
        }
    }

    class MockViewController: UIViewController, EmbraceViewControllerCustomization {
        var nameForViewControllerInEmbrace = "Custom Title"
        var shouldCaptureViewInEmbrace = true
    }

    class MockInteractableViewController: MockViewController, InteractableViewController {

    }

#endif
