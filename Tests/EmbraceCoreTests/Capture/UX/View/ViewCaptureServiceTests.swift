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

class ViewCaptureServiceTests: XCTestCase {

    var handler: MockUIViewControllerHandler!
    var service: ViewCaptureService!

    override func setUpWithError() throws {
        handler = MockUIViewControllerHandler()
        service = ViewCaptureService(options: ViewCaptureService.Options(), handler: handler, lock: NSLock())
        service.install(otel: nil)
        service.start()
    }

    func test_viewDidLoad() {
        // given a ViewCaptureService
        // when viewDidLoad is called on a UIViewController
        let vc = MockViewController()
        vc.viewDidLoad()

        // then the appropiate methods are called on the handler
        XCTAssert(handler.onViewDidLoadStartCalled)
        XCTAssert(handler.onViewDidLoadEndCalled)
    }

    func test_viewWillAppear_wontCallMethodsIfStateIsNotSet() {
        let vc = MockViewController()
        vc.emb_instrumentation_state = nil
        vc.viewWillAppear(false)

        XCTAssertFalse(handler.onViewWillAppearStartCalled)
        XCTAssertFalse(handler.onViewWillAppearEndCalled)
        XCTAssertFalse(handler.onViewIsAppearingStartCalled)
    }

    func test_viewWillAppear_wontCallsMethodsIfStateIsSet() {
        // given a ViewCaptureService
        // when viewWillAppear is called on a UIViewController
        let vc = MockViewController()
        vc.emb_instrumentation_state = .init()
        vc.viewWillAppear(false)

        // then the appropiate methods are called on the handler
        XCTAssertTrue(handler.onViewWillAppearStartCalled)
        XCTAssertTrue(handler.onViewWillAppearEndCalled)
        XCTAssertTrue(handler.onViewIsAppearingStartCalled)
    }

    func test_viewDidAppear() {
        // given a ViewCaptureService
        // when viewDidAppear is called on a UIViewController
        let vc = MockViewController()
        vc.viewDidAppear(false)

        // then the appropiate methods are called on the handler
        XCTAssert(handler.onViewDidAppearStartCalled)
        XCTAssert(handler.onViewDidAppearEndCalled)
    }

    func test_viewDidDisappear() {
        // given a ViewCaptureService
        // when viewDidDisappear is called on a UIViewController
        let vc = MockViewController()
        vc.viewDidDisappear(false)

        // then the appropiate methods are called on the handler
        XCTAssert(handler.onViewDidDisappearCalled)
    }
}

#endif
