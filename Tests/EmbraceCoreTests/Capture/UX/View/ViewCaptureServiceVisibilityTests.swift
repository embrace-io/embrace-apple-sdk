//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import XCTest
    @testable import EmbraceCore
    import TestSupport

    /// Runs the real `UIViewControllerHandler` through the `ViewCaptureService` swizzles,
    /// so the `viewDidAppear` guards are covered along with the handler.
    class ViewCaptureServiceVisibilityTests: SwizzlerTestCase {

        var otel: MockOTelSignalsHandler!
        var service: ViewCaptureService!

        override func setUpWithError() throws {
            try super.setUpWithError()
            otel = MockOTelSignalsHandler()
            service = ViewCaptureService(
                options: ViewCaptureService.Options(instrumentVisibility: true, instrumentFirstRender: false),
                // runs the handler's work inline so every call has finished by the time it returns
                handler: UIViewControllerHandler(queue: MockQueue()),
                lock: NSLock()
            )
            service.install(otel: otel)
            service.start()
        }

        override func tearDownWithError() throws {
            restoreSwizzleCacheAdditions()
            service = nil
            otel = nil
            try super.tearDownWithError()
        }

        func test_firstRenderOff_everyAppearanceRecordsScreenView() {
            // given a view controller with first-render instrumentation off
            let vc = MockViewController()

            // when it appears and disappears three times
            for _ in 0..<3 {
                vc.viewDidAppear(false)
                vc.viewDidDisappear(false)
            }

            // then every appearance records a screen view, and each one is ended
            XCTAssertEqual(otel.startedSpans.filter { $0.name == "emb-screen-view" }.count, 3)
            XCTAssertEqual(otel.endedSpans.filter { $0.name == "emb-screen-view" }.count, 3)
        }
    }

#endif
