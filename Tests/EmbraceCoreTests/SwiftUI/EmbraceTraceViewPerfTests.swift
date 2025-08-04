#if canImport(UIKit)

    import UIKit
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import OpenTelemetryApi
    import OpenTelemetrySdk
    import SwiftUI
    import TestSupport
    import XCTest

    @testable import EmbraceCore

    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
    @MainActor
    final class EmbraceTraceViewPerfTests: XCTestCase {

        var spanProcessor: MockSpanProcessor!
        var mockOTel: MockEmbraceOpenTelemetry!
        var mockConfig: MockEmbraceConfigurable!
        var mockLogger: MockLogger!
        var traceViewLogger: EmbraceTraceViewLogger!
        var traceViewContext: EmbraceTraceViewContext!

        override func setUpWithError() throws {
            mockOTel = MockEmbraceOpenTelemetry()
            spanProcessor = mockOTel.spanProcessor
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
            spanProcessor = nil
            EmbraceOTel.setup(spanProcessors: [])
            mockOTel = nil
            mockConfig = nil
            mockLogger = nil
            traceViewLogger = nil
            traceViewContext = nil
        }

        func runLayout() {
            let traceView = EmbraceTraceView("BenchmarkScreen") {
                Text("Performance Test")
            }
            .environment(\.embraceTraceViewLogger, traceViewLogger)
            .environment(\.embraceTraceViewContext, traceViewContext)

            let hostingController = UIHostingController(rootView: traceView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
            window.rootViewController = hostingController
            window.makeKeyAndVisible()

            hostingController.loadViewIfNeeded()
            hostingController.view.layoutIfNeeded()

            window.isHidden = true
        }

        func testEmbraceTraceViewEnabledPerformance() async {
            mockConfig.isSwiftUiViewInstrumentationEnabled = true
            measure {
                runLayout()
            }
        }

        func testEmbraceTraceViewDisabledPerformance() async {
            mockConfig.isSwiftUiViewInstrumentationEnabled = false
            measure {
                runLayout()
            }
        }

    }

#endif
