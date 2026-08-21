#if canImport(UIKit) && !os(watchOS)

    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import SwiftUI
    import TestSupport
    import XCTest
    import UIKit

    @testable import EmbraceCore

    extension RunLoop {
        @MainActor
        func waitForNextTick() async {
            await withUnsafeContinuation { continuation in
                perform(inModes: [.common]) {
                    continuation.resume()
                }
            }
        }
    }

    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
    final class EmbraceTraceViewTests: XCTestCase {

        var mockOTel: MockOTelSignalsHandler!
        var mockConfig: MockEmbraceConfigurable!
        var mockLogger: MockLogger!
        var traceViewLogger: EmbraceTraceViewLogger!
        var traceViewContext: EmbraceTraceViewContext!

        override func setUpWithError() throws {
            mockOTel = MockOTelSignalsHandler()
            mockConfig = MockEmbraceConfigurable(isSwiftUiViewInstrumentationEnabled: true)
            mockLogger = MockLogger()

            traceViewLogger = EmbraceTraceViewLogger(
                otel: mockOTel,
                logger: mockLogger,
                config: mockConfig
            )

            traceViewContext = EmbraceTraceViewContext()
        }

        override func tearDownWithError() throws {
            mockOTel = nil
            mockConfig = nil
            mockLogger = nil
            traceViewLogger = nil
            traceViewContext = nil
        }

        @MainActor
        func testEmbraceTraceViewCreatesSpanWhenTracingEnabled() async {
            // Given: tracing is enabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we create and render an EmbraceTraceView
            let traceView = EmbraceTraceView("TestScreen") {
                Text("Hello World")
            }
            .environment(\.embraceTraceViewLogger, traceViewLogger)
            .environment(\.embraceTraceViewContext, traceViewContext)

            let hostingController = UIHostingController(rootView: traceView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            // Force the view to render
            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            // Wait for run loop to process spans
            await RunLoop.main.waitForNextTick()

            // Then: verify spans were created
            let allSpans = mockOTel.startedSpans + mockOTel.endedSpans
            let testScreenSpans = allSpans.filter { $0.name.contains("TestScreen") }

            print("Total spans created: \(allSpans.count)")
            print("TestScreen spans: \(testScreenSpans.count)")
            for span in allSpans {
                print("Span: \(span.name)")
            }

            XCTAssertGreaterThan(testScreenSpans.count, 0, "Should create at least one span for TestScreen")

            // Cleanup
            window.isHidden = true
        }

        @MainActor
        func testEmbraceTraceViewWithTracingDisabled() async {
            // Given: tracing is disabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = false

            // When: we create and render an EmbraceTraceView
            let traceView = EmbraceTraceView("DisabledScreen") {
                Text("Should Still Render")
            }
            .environment(\.embraceTraceViewLogger, traceViewLogger)
            .environment(\.embraceTraceViewContext, traceViewContext)

            let hostingController = UIHostingController(rootView: traceView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            await RunLoop.main.waitForNextTick()

            // Then: no spans should be created
            let allSpans = mockOTel.startedSpans + mockOTel.endedSpans
            XCTAssertEqual(allSpans.count, 0, "No spans should be created when tracing is disabled")

            // But the view should still render successfully
            XCTAssertNotNil(hostingController.view)

            window.isHidden = true
        }

        @MainActor
        func testEmbraceTraceViewWithCustomAttributes() async {
            // Given: tracing is enabled with custom attributes
            mockConfig.isSwiftUiViewInstrumentationEnabled = true
            let attributes = ["screen_type": "home", "feature": "welcome"]

            // When: we create and render an EmbraceTraceView with attributes
            let traceView = EmbraceTraceView("HomeScreen", attributes: attributes) {
                Text("Welcome Home")
            }
            .environment(\.embraceTraceViewLogger, traceViewLogger)
            .environment(\.embraceTraceViewContext, traceViewContext)

            let hostingController = UIHostingController(rootView: traceView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            await RunLoop.main.waitForNextTick()

            // Then: spans should include custom attributes
            let allSpans = mockOTel.startedSpans + mockOTel.endedSpans
            let homeScreenSpans = allSpans.filter { $0.name.contains("HomeScreen") }

            XCTAssertGreaterThan(homeScreenSpans.count, 0, "Should create spans for HomeScreen")

            // Verify at least one span has the custom attributes
            let spansWithAttributes = homeScreenSpans.filter { span in
                span.attributes["screen_type"]?.description == "home"
                    && span.attributes["feature"]?.description == "welcome"
            }
            XCTAssertGreaterThan(spansWithAttributes.count, 0, "Should have spans with custom attributes")

            window.isHidden = true
        }

        @MainActor
        func testEmbraceTraceViewSpanNaming() async {
            // Given: tracing is enabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we create and render an EmbraceTraceView opted in to body tracking
            let traceView = EmbraceTraceView("ProfileScreen", trackBodyEvaluations: true) {
                Text("User Profile")
            }
            .environment(\.embraceTraceViewLogger, traceViewLogger)
            .environment(\.embraceTraceViewContext, traceViewContext)

            let hostingController = UIHostingController(rootView: traceView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            await RunLoop.main.waitForNextTick()

            // Then: verify specific span names follow expected format
            let allSpans = mockOTel.startedSpans + mockOTel.endedSpans
            let spanNames = allSpans.map { $0.name }

            XCTAssertTrue(spanNames.contains("emb-swiftui.view.ProfileScreen.render-loop"))
            XCTAssertTrue(spanNames.contains("emb-swiftui.view.ProfileScreen.body"))
            XCTAssertTrue(spanNames.contains("emb-swiftui.view.ProfileScreen.appear"))
            XCTAssertTrue(spanNames.contains("emb-swiftui.view.ProfileScreen.time-to-first-render"))

            window.isHidden = true
        }

        // MARK: - trackBodyEvaluations

        /// Renders `view` in a key window and waits for the pending run loop tick, so that
        /// cycled spans have been ended by the time the caller inspects `mockOTel`.
        @MainActor
        private func render<V: View>(_ view: V) async {
            let hostingController = UIHostingController(
                rootView:
                    view
                    .environment(\.embraceTraceViewLogger, traceViewLogger)
                    .environment(\.embraceTraceViewContext, traceViewContext)
            )
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            await RunLoop.main.waitForNextTick()

            window.isHidden = true
        }

        @MainActor
        private func spanNames() -> [String] {
            (mockOTel.startedSpans + mockOTel.endedSpans).map { $0.name }
        }

        @MainActor
        func testBodyAndRenderLoopSpansSuppressedByDefault() async {
            // Given: tracing is enabled and trackBodyEvaluations is left at its default
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we render an EmbraceTraceView without opting in
            await render(
                EmbraceTraceView("DefaultScreen") {
                    Text("Body spans off")
                }
            )

            // Then: neither the body nor the render-loop span is emitted...
            let names = spanNames()
            XCTAssertFalse(
                names.contains("emb-swiftui.view.DefaultScreen.body"),
                "Body spans must be opt-in")
            XCTAssertFalse(
                names.contains("emb-swiftui.view.DefaultScreen.render-loop"),
                "The render-loop span has nothing to group when body spans are off")

            // ...while the always-on spans are untouched.
            XCTAssertTrue(names.contains("emb-swiftui.view.DefaultScreen.appear"))
            XCTAssertTrue(names.contains("emb-swiftui.view.DefaultScreen.time-to-first-render"))
        }

        @MainActor
        func testBodyAndRenderLoopSpansEmittedWhenOptedIn() async {
            // Given: tracing is enabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we render an EmbraceTraceView that opts in
            await render(
                EmbraceTraceView("OptedInScreen", trackBodyEvaluations: true) {
                    Text("Body spans on")
                }
            )

            // Then: both spans are emitted
            let names = spanNames()
            XCTAssertTrue(names.contains("emb-swiftui.view.OptedInScreen.body"))
            XCTAssertTrue(names.contains("emb-swiftui.view.OptedInScreen.render-loop"))
        }

        @MainActor
        func testEmbraceTraceModifierSuppressesBodySpansByDefault() async {
            // Given: tracing is enabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we use the `.embraceTrace` modifier rather than the view directly
            await render(Text("Modifier").embraceTrace("ModifierScreen"))

            // Then: the default flows through the modifier
            let names = spanNames()
            XCTAssertFalse(names.contains("emb-swiftui.view.ModifierScreen.body"))
            XCTAssertFalse(names.contains("emb-swiftui.view.ModifierScreen.render-loop"))
            XCTAssertTrue(names.contains("emb-swiftui.view.ModifierScreen.appear"))
        }

        @MainActor
        func testEmbraceTraceModifierEmitsBodySpansWhenOptedIn() async {
            // Given: tracing is enabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we opt in through the modifier
            await render(
                Text("Modifier").embraceTrace("ModifierOptInScreen", trackBodyEvaluations: true)
            )

            // Then: body spans are emitted
            let names = spanNames()
            XCTAssertTrue(names.contains("emb-swiftui.view.ModifierOptInScreen.body"))
            XCTAssertTrue(names.contains("emb-swiftui.view.ModifierOptInScreen.render-loop"))
        }

        @MainActor
        func testAppearSpanIsRootWhenBodyEvaluationsAreNotTracked() async {
            // Given: tracing is enabled and body tracking is off, so there is no render-loop span
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we render without opting in
            await render(
                EmbraceTraceView("RootAppearScreen") {
                    Text("No parent")
                }
            )

            // Then: the appear span has no parent rather than attaching to an unrelated cycle span
            let appearSpans = mockOTel.startedSpans.filter {
                $0.name == "emb-swiftui.view.RootAppearScreen.appear"
            }
            XCTAssertFalse(appearSpans.isEmpty, "Expected an appear span")
            for span in appearSpans {
                XCTAssertNil(span.parentSpanId)
            }
        }

        @MainActor
        func testAppearSpanNestsUnderRenderLoopWhenBodyEvaluationsAreTracked() async throws {
            // Given: tracing is enabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we render with body tracking on
            await render(
                EmbraceTraceView("NestedAppearScreen", trackBodyEvaluations: true) {
                    Text("Parented")
                }
            )

            // Then: the appear span nests under this view's render-loop span
            let renderLoop = mockOTel.startedSpans.first {
                $0.name == "emb-swiftui.view.NestedAppearScreen.render-loop"
            }
            let appearSpans = mockOTel.startedSpans.filter {
                $0.name == "emb-swiftui.view.NestedAppearScreen.appear"
            }

            let renderLoopId = try XCTUnwrap(renderLoop?.context.spanId, "Expected a render-loop span")
            XCTAssertFalse(appearSpans.isEmpty, "Expected an appear span")
            for span in appearSpans {
                XCTAssertEqual(span.parentSpanId, renderLoopId)
            }
        }

        @MainActor
        func testContentCompleteSpanStillEmittedWhenBodyEvaluationsAreNotTracked() async {
            // Given: tracing is enabled, body tracking off, and a content-complete trigger that flips.
            // The content-complete bookkeeping lives inside `body`, so this guards against the
            // opt-out accidentally short-circuiting it.
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            func view(contentComplete: Bool) -> some View {
                EmbraceTraceView("ContentCompleteScreen", contentComplete: contentComplete) {
                    Text("Loading")
                }
                .environment(\.embraceTraceViewLogger, traceViewLogger)
                .environment(\.embraceTraceViewContext, traceViewContext)
            }

            let hostingController = UIHostingController(rootView: view(contentComplete: false))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()
            await RunLoop.main.waitForNextTick()

            // When: the content-complete value changes, forcing a re-evaluation of `body`
            hostingController.rootView = view(contentComplete: true)
            hostingController.view.setNeedsLayout()
            hostingController.view.layoutIfNeeded()
            await RunLoop.main.waitForNextTick()

            // Then: the content-complete span is emitted, and body spans still are not
            let names = spanNames()
            XCTAssertTrue(
                names.contains("emb-swiftui.view.ContentCompleteScreen.time-to-first-content-complete"),
                "Content-complete must be unaffected by the body-span opt-out")
            XCTAssertFalse(names.contains("emb-swiftui.view.ContentCompleteScreen.body"))

            window.isHidden = true
        }

        @MainActor
        func testMultipleEmbraceTraceViews() async {
            // Given: tracing is enabled
            mockConfig.isSwiftUiViewInstrumentationEnabled = true

            // When: we create multiple EmbraceTraceViews in a container
            let containerView = VStack {
                EmbraceTraceView("HeaderView") {
                    Text("Header")
                }
                EmbraceTraceView("ContentView") {
                    Text("Main Content")
                }
                EmbraceTraceView("FooterView") {
                    Text("Footer")
                }
            }
            .environment(\.embraceTraceViewLogger, traceViewLogger)
            .environment(\.embraceTraceViewContext, traceViewContext)

            let hostingController = UIHostingController(rootView: containerView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            await RunLoop.main.waitForNextTick()

            // Then: each view should create its own spans
            let allSpans = mockOTel.startedSpans + mockOTel.endedSpans

            let headerSpans = allSpans.filter { $0.name.contains("HeaderView") }
            let contentSpans = allSpans.filter { $0.name.contains("ContentView") }
            let footerSpans = allSpans.filter { $0.name.contains("FooterView") }

            XCTAssertGreaterThan(headerSpans.count, 0, "Should create spans for HeaderView")
            XCTAssertGreaterThan(contentSpans.count, 0, "Should create spans for ContentView")
            XCTAssertGreaterThan(footerSpans.count, 0, "Should create spans for FooterView")

            window.isHidden = true
        }
    }

#endif
