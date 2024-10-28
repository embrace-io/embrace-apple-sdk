//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import XCTest
import UIKit
@testable import EmbraceCore
import EmbraceOTelInternal
import TestSupport

final class ViewCaptureServiceTests: XCTestCase {
    private var service: ViewCaptureService!
    private var otel: MockEmbraceOpenTelemetry!

    override func setUpWithError() throws {
        otel = MockEmbraceOpenTelemetry()
        service = ViewCaptureService()
    }

    override func tearDownWithError() throws {
        service = nil
        otel = nil
    }

    func test_viewDidAppear() throws {
        // given an installed and started view capture service
        service.install(otel: otel)
        service.start()

        // when a view appears
        let vc = UIViewController()
        vc.viewDidAppear(true)

        // then the event is captured
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 1)
        XCTAssertEqual(otel.spanProcessor.startedSpans[0].embType, .view)
        XCTAssertEqual(otel.spanProcessor.startedSpans[0].name, "emb-screen-view")
    }

    func test_viewDidDisappear() throws {
        // given an installed and started view capture service
        service.install(otel: otel)
        service.start()

        // when a view appears and then disappears
        let vc = UIViewController()
        vc.viewDidAppear(true)
        vc.viewDidDisappear(true)

        // then the events are captured
        XCTAssertEqual(otel.spanProcessor.endedSpans.count, 1)
        XCTAssertEqual(otel.spanProcessor.endedSpans[0].embType, .view)
        XCTAssertEqual(otel.spanProcessor.endedSpans[0].name, "emb-screen-view")
    }

    func test_viewDeallocates_associatedSpanDeallocatesToo() throws {
        // given an installed and started view capture service
        service.install(otel: otel)
        service.start()

        // when a view appears
        var vc: UIViewController? = UIViewController()
        vc!.viewDidAppear(true)

        // It has an associated span
        weak var span = vc!.emb_associatedSpan
        XCTAssertNotNil(span)

        // the start events are captured
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 1)
        XCTAssertEqual(otel.spanProcessor.startedSpans[0].embType, .view)
        XCTAssertEqual(otel.spanProcessor.startedSpans[0].name, "emb-screen-view")

        // when view is deallocated without didDisappear, span is also deleted
        vc = nil
        XCTAssertEqual(otel.spanProcessor.endedSpans.count, 0)
        XCTAssertNil(span)
    }

    func test_service_uninstalled() throws {
        // given an instantiated but not installed view capture service

        // when a view appears
        let vc = UIViewController()
        vc.viewDidAppear(true)

        // then the event is not captured
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 0)
        XCTAssertEqual(otel.spanProcessor.endedSpans.count, 0)
    }

    func test_service_notStarted() throws {
        // given an installed but not started view capture service
        service.install(otel: otel)

        // when a view appears
        let vc = UIViewController()
        vc.viewDidAppear(true)

        // then the event is not captured
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 0)
        XCTAssertEqual(otel.spanProcessor.endedSpans.count, 0)
    }

    func test_service_stopped() throws {
        // given an installed but stopped view capture service
        service.install(otel: otel)
        service.start()
        service.stop()

        // when a view appears
        let vc = UIViewController()
        vc.viewDidAppear(true)

        // then the event is not captured
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 0)
        XCTAssertEqual(otel.spanProcessor.endedSpans.count, 0)
    }

    func test_ViewName_title() {
        // given an installed and started tap capture service
        service.install(otel: otel)
        service.start()

        // when a view appears
        let vc = UIViewController()
        vc.title = "A custom title"
        vc.viewDidAppear(true)

        // then the view is captured with the correct view name
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 1)
        XCTAssertEqual(otel.spanProcessor.startedSpans[0].attributes["view.title"], .string("A custom title"))
        XCTAssertEqual(otel.spanProcessor.startedSpans[0].attributes["view.name"], .string("UIViewController"))
    }

    func test_ViewName_embName() {
        // given an installed and started tap capture service
        service.install(otel: otel)
        service.start()

        // when a view appears
        let vc = ViewCaptureTestViewController()
        vc.customTitle = "a customized class title"
        vc.viewDidAppear(true)

        // then the view is captured with the correct title name
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 1)
        XCTAssertEqual(otel.spanProcessor.startedSpans[0].attributes["view.title"], .string("a customized class title"))
        XCTAssertEqual(
            otel.spanProcessor.startedSpans[0].attributes["view.name"],
            .string("ViewCaptureTestViewController")
        )
    }

    func test_manuallyIgnoreView() throws {
        // given an installed and started view capture service
        service.install(otel: otel)
        service.start()

        // when a view is set to manually be ignored
        let vc = ViewCaptureTestViewController()
        vc.logView = false
        // then appears and disappears
        vc.viewDidAppear(true)
        vc.viewDidDisappear(true)

        // then the events are not captured
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 0)
        XCTAssertEqual(otel.spanProcessor.endedSpans.count, 0)
    }
}

class ViewCaptureTestViewController: UIViewController {
    var customTitle = "Custom Title"
    var logView = true
}

extension ViewCaptureTestViewController: EmbraceViewControllerCustomization {
    var nameForViewControllerInEmbrace: String? { customTitle }
    var shouldCaptureViewInEmbrace: Bool { logView }
}

#endif
