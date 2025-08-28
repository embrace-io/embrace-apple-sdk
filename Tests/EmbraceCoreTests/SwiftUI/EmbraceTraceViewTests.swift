#if canImport(UIKit) && !os(watchOS)

    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import SwiftUI
    import TestSupport
    import XCTest
    import UIKit

    @testable import EmbraceCore

    extension RunLoop {
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

            // When: we create and render an EmbraceTraceView
            let traceView = EmbraceTraceView("ProfileScreen") {
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
