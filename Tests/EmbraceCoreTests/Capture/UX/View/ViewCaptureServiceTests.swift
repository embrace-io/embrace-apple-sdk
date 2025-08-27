//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import XCTest
    @testable import EmbraceCore
    import OpenTelemetryApi
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

        func test_blockList_creation() {
            // given a capture service with a block list
            let blockList = ViewControllerBlockList(
                types: [MockViewController.self], names: ["Test"], blockHostingControllers: true)
            let options = ViewCaptureService.Options(
                instrumentVisibility: true, instrumentFirstRender: true, viewControllerBlockList: blockList)
            service = ViewCaptureService(options: options, handler: handler, lock: NSLock())

            // then it has the correct block list
            XCTAssert(service.blockList.safeValue.types.contains { $0 == MockViewController.self })
            XCTAssert(service.blockList.safeValue.names.contains("TEST"))
            XCTAssert(service.blockList.safeValue.blockHostingControllers)
        }

        func test_blockList_remoteConfig() {
            // given a capture service with a block list
            let blockList = ViewControllerBlockList(
                types: [MockViewController.self],
                names: ["Test"],
                blockHostingControllers: true
            )
            let options = ViewCaptureService.Options(
                instrumentVisibility: true,
                instrumentFirstRender: true,
                viewControllerBlockList: blockList
            )
            service = ViewCaptureService(options: options, handler: handler, lock: NSLock())

            // then it has the correct block list
            XCTAssert(service.blockList.safeValue.types.contains { $0 == MockViewController.self })
            XCTAssert(service.blockList.safeValue.names.contains("TEST"))
            XCTAssert(service.blockList.safeValue.blockHostingControllers)

            // when the remote config changes
            let config = EditableConfig()
            config.viewControllerClassNameBlocklist = ["MyCustomViewController", "MySpecialViewController"]
            // Is config says it should capture, then it capture service shouldn't block
            config.uiInstrumentationCaptureHostingControllers = true
            Embrace.notificationCenter.post(name: .embraceConfigUpdated, object: config)

            // then the blocklist is updated
            XCTAssert(service.blockList.safeValue.types.isEmpty)
            XCTAssert(service.blockList.safeValue.names.contains("MYCUSTOMVIEWCONTROLLER"))
            XCTAssert(service.blockList.safeValue.names.contains("MYSPECIALVIEWCONTROLLER"))
            XCTAssertEqual(service.blockList.safeValue.names.count, 2)
            XCTAssertFalse(service.blockList.safeValue.blockHostingControllers)
        }
    }

#endif
