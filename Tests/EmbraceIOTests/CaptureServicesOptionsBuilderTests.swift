//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCore
import XCTest

@testable import EmbraceIO

class CaptureServicesOptionsBuilderTests: XCTestCase {

    func test_defaults() throws {
        // given a builder
        let builder = CaptureServicesOptionsBuilder()

        // when adding the defaults
        builder.addDefaults()

        // then the result contains all the default services
        let options = builder.build()

        XCTAssertNotNil(options.urlSession)

        #if canImport(UIKit) && !os(watchOS)
            XCTAssertNotNil(options.tap)
            XCTAssertNotNil(options.view)
        #endif
        #if canImport(WebKit)
            XCTAssertNotNil(options.webView)
        #endif

        XCTAssertNil(options.pushNotification)
        XCTAssertTrue(options.lowMemoryWarning)
        XCTAssertTrue(options.lowPowerMode)
        XCTAssertFalse(options.hang)

        XCTAssertEqual(options.customServices.count, 0)
    }

    func test_urlSession() throws {
        // given a builder
        let builder = CaptureServicesOptionsBuilder()

        // when adding custom url session options
        builder.addUrlSessionCaptureService(
            withOptions:
                .init(
                    injectTracingHeader: false,
                    requestsDataSource: nil,
                    ignoredURLs: ["test"]
                )
        )

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertFalse(options.urlSession!.injectTracingHeader)
        XCTAssertNil(options.urlSession!.requestsDataSource)
        XCTAssertEqual(options.urlSession!.ignoredURLs, ["test"])
    }

    func test_urlSession_remove() throws {
        // given a builder with default services
        let builder = CaptureServicesOptionsBuilder()
        builder.addDefaults()

        // when removing url session
        builder.remove(embraceType: .urlSession)

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertNil(options.urlSession)
    }

    #if canImport(UIKit) && !os(watchOS)
        func test_tap() throws {
            // given a builder
            let builder = CaptureServicesOptionsBuilder()

            // when adding custom tap options
            builder.addTapCaptureService(
                withOptions:
                    .init(
                        ignoredViewTypes: [],
                        captureTapCoordinates: false,
                        tapPhase: .onEnd,
                        delegate: nil
                    )
            )

            // then the result contains the correct options
            let options = builder.build()

            XCTAssertEqual(options.tap!.ignoredViewTypes.count, 0)
            XCTAssertFalse(options.tap!.captureTapCoordinates)
            XCTAssertEqual(options.tap!.tapPhase, .onEnd)
            XCTAssertNil(options.tap!.delegate)
        }

        func test_tap_remove() throws {
            // given a builder with default services
            let builder = CaptureServicesOptionsBuilder()
            builder.addDefaults()

            // when removing tap
            builder.remove(embraceType: .tap)

            // then the result contains the correct options
            let options = builder.build()

            XCTAssertNil(options.tap)
        }

        func test_view() throws {
            // given a builder
            let builder = CaptureServicesOptionsBuilder()

            // when adding custom view options
            builder.addViewCaptureService(
                withOptions:
                    .init(
                        instrumentVisibility: false,
                        instrumentFirstRender: false,
                        viewControllerBlockList: ViewControllerBlockList(types: [], names: ["test"], blockHostingControllers: false)
                    )
            )

            // then the result contains the correct options
            let options = builder.build()

            XCTAssertFalse(options.view!.instrumentVisibility)
            XCTAssertFalse(options.view!.instrumentFirstRender)
            XCTAssertEqual(options.view!.viewControllerBlockList.types.count, 0)
            XCTAssertEqual(options.view!.viewControllerBlockList.names, ["TEST"])
            XCTAssertFalse(options.view!.viewControllerBlockList.blockHostingControllers)
        }

        func test_view_remove() throws {
            // given a builder with default services
            let builder = CaptureServicesOptionsBuilder()
            builder.addDefaults()

            // when removing view
            builder.remove(embraceType: .view)

            // then the result contains the correct options
            let options = builder.build()

            XCTAssertNil(options.view)
        }
    #endif

    #if canImport(WebKit)
        func test_webView() throws {
            // given a builder
            let builder = CaptureServicesOptionsBuilder()

            // when adding custom webview options
            builder.addWebViewCaptureService(
                withOptions:
                    .init(stripQueryParams: true)
            )

            // then the result contains the correct options
            let options = builder.build()

            XCTAssertTrue(options.webView!.stripQueryParams)
        }

        func test_webView_remove() throws {
            // given a builder with default services
            let builder = CaptureServicesOptionsBuilder()
            builder.addDefaults()

            // when removing web view
            builder.remove(embraceType: .webView)

            // then the result contains the correct options
            let options = builder.build()

            XCTAssertNil(options.webView)
        }
    #endif

    func test_pushNotification() throws {
        // given a builder
        let builder = CaptureServicesOptionsBuilder()

        // when adding custom push notification options
        builder.addPushNotificationCaptureService(
            withOptions:
                .init(captureData: true)
        )

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertTrue(options.pushNotification!.captureData)
    }

    func test_pushNotification_remove() throws {
        // given a builder with default services
        let builder = CaptureServicesOptionsBuilder()
        builder.addDefaults()

        // when removing push notification
        builder.remove(embraceType: .pushNotification)

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertNil(options.pushNotification)
    }

    func test_lowMemoryWarning() throws {
        // given a builder
        let builder = CaptureServicesOptionsBuilder()

        // when adding low memory warning
        builder.addLowMemoryWarningCaptureService()

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertTrue(options.lowMemoryWarning)
    }

    func test_lowMemoryWarning_remove() throws {
        // given a builder with default services
        let builder = CaptureServicesOptionsBuilder()
        builder.addDefaults()

        // when removing low memory warning
        builder.remove(embraceType: .lowMemoryWarning)

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertFalse(options.lowMemoryWarning)
    }

    func test_lowPowerMode() throws {
        // given a builder
        let builder = CaptureServicesOptionsBuilder()

        // when adding low power mode
        builder.addLowPowerModeCaptureService()

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertTrue(options.lowPowerMode)
    }

    func test_lowPowerMode_remove() throws {
        // given a builder with default services
        let builder = CaptureServicesOptionsBuilder()
        builder.addDefaults()

        // when removing low power mode
        builder.remove(embraceType: .lowPowerMode)

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertFalse(options.lowPowerMode)
    }

    func test_hang() throws {
        // given a builder
        let builder = CaptureServicesOptionsBuilder()

        // when adding hang
        builder.addHangCaptureService()

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertTrue(options.hang)
    }

    func test_hang_remove() throws {
        // given a builder with default services
        let builder = CaptureServicesOptionsBuilder()
        builder.addDefaults()

        // when removing hang
        builder.remove(embraceType: .hang)

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertFalse(options.hang)
    }

    func test_customService() throws {
        // given a builder
        let builder = CaptureServicesOptionsBuilder()

        // when adding a custom service
        builder.add(FakeCaptureService())

        // then the result contains the correct options
        let options = builder.build()

        XCTAssertEqual(options.customServices.count, 1)
        XCTAssertTrue(options.customServices[0] is FakeCaptureService)
    }

    func test_customService_remove() throws {
        // given a builder with a custom service
        let builder = CaptureServicesOptionsBuilder()
        builder.add(FakeCaptureService())

        // when removing the service
        builder.remove(ofType: FakeCaptureService.self)

        // then the result doesn't contain the service
        let options = builder.build()

        XCTAssertEqual(options.customServices.count, 0)
    }

    func test_customService_replace() throws {
        // given a builder with a custom service
        let builder = CaptureServicesOptionsBuilder()
        builder.add(FakeCaptureService())

        // when adding a custom service of the same type
        let service = FakeCaptureService()
        service.testValue = 9999
        builder.add(service)

        // then the result contains the service that was added last
        let options = builder.build()

        XCTAssertEqual(options.customServices.count, 1)
        XCTAssertEqual((options.customServices[0] as! FakeCaptureService).testValue, 9999)
    }

    func test_customService_embraceType() throws {
        // given a builder with default services
        let builder = CaptureServicesOptionsBuilder()
        builder.addDefaults()

        // when adding a custom service of an embrace type
        builder.add(TapCaptureService())

        // then the service will be added as a custom service
        let options = builder.build()

        XCTAssertEqual(options.customServices.count, 1)
        XCTAssertTrue(options.customServices[0] is TapCaptureService)
    }
}

class FakeCaptureService: CaptureService {
    var testValue: Int = 0
}
