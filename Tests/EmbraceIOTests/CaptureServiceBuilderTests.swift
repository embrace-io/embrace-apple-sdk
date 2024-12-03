//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceIO
import EmbraceCore
import XCTest

// swiftlint:disable force_cast

class CaptureServiceBuilderTests: XCTestCase {

    func test_defaults() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding the defaults
        builder.addDefaults()

        // then the list contains all the default services
        let list = builder.build()

        var count = 3

        XCTAssertNotNil(list.first(where: { $0 is URLSessionCaptureService }))

#if canImport(UIKit) && !os(watchOS)
        count += 2
        XCTAssertNotNil(list.first(where: { $0 is TapCaptureService }))
        XCTAssertNotNil(list.first(where: { $0 is ViewCaptureService }))
#endif
#if canImport(WebKit)
        count += 1
        XCTAssertNotNil(list.first(where: { $0 is WebViewCaptureService }))
#endif

        XCTAssertNotNil(list.first(where: { $0 is LowMemoryWarningCaptureService }))
        XCTAssertNotNil(list.first(where: { $0 is LowPowerModeCaptureService }))

        XCTAssertEqual(list.count, count)

    }

    func test_defaultsWithNonEmptyList() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a URLSessionCaptureService with custom options
        let options = URLSessionCaptureService.Options(injectTracingHeader: false, requestsDataSource: nil, ignoredURLs: [])
        builder.add(.urlSession(options: options))

        // when adding the defaults
        builder.addDefaults()

        // then the list contains the correct services
        let list = builder.build()

        var count = 3

#if canImport(UIKit) && !os(watchOS)
        count += 2
        XCTAssertNotNil(list.first(where: { $0 is TapCaptureService }))
        XCTAssertNotNil(list.first(where: { $0 is ViewCaptureService }))
#endif
#if canImport(WebKit)
        count += 1
        XCTAssertNotNil(list.first(where: { $0 is WebViewCaptureService }))
#endif

        XCTAssertNotNil(list.first(where: { $0 is LowMemoryWarningCaptureService }))
        XCTAssertNotNil(list.first(where: { $0 is LowPowerModeCaptureService }))
        XCTAssertNotNil(list.first(where: { $0 is LowMemoryWarningCaptureService }))
        XCTAssertNotNil(list.first(where: { $0 is LowPowerModeCaptureService }))

        let service = list.first(where: { $0 is URLSessionCaptureService }) as! URLSessionCaptureService
        XCTAssertFalse(service.options.injectTracingHeader)
        XCTAssertNil(service.options.requestsDataSource)

        XCTAssertEqual(list.count, count)
    }

    func test_remove() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding the defaults
        builder.addDefaults()

        // when removing some services
        builder.remove(ofType: URLSessionCaptureService.self)

#if canImport(UIKit) && !os(watchOS)
        builder.remove(ofType: TapCaptureService.self)
        builder.remove(ofType: ViewCaptureService.self)
#endif

        // then the list contains the correct services
        let list = builder.build()

        var count = 2

#if canImport(WebKit)
        count += 1
        XCTAssertNotNil(list.first(where: { $0 is WebViewCaptureService }))
#endif
        XCTAssertNotNil(list.first(where: { $0 is LowMemoryWarningCaptureService }))
        XCTAssertNotNil(list.first(where: { $0 is LowPowerModeCaptureService }))

        XCTAssertEqual(list.count, count)
    }

    func test_replace() {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a default URLSessionCaptureService
        builder.add(.urlSession())

        // and then adding it again
        let options = URLSessionCaptureService.Options(injectTracingHeader: false, requestsDataSource: nil, ignoredURLs: [])
        builder.add(.urlSession(options: options))

        // then the list contains the correct services
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        let service = list[0] as! URLSessionCaptureService
        XCTAssertFalse(service.options.injectTracingHeader)
        XCTAssertNil(service.options.requestsDataSource)
    }

    func test_addUrlSessionCaptureService() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a URLSessionCaptureService
        let options = URLSessionCaptureService.Options(injectTracingHeader: false, requestsDataSource: nil, ignoredURLs: [])
        builder.add(.urlSession(options: options))

        // then the list contains the capture service
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        let service = list[0] as! URLSessionCaptureService
        XCTAssertFalse(service.options.injectTracingHeader)
        XCTAssertNil(service.options.requestsDataSource)
    }

#if canImport(UIKit) && !os(watchOS)
    func test_addTapCaptureService() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a TapCaptureService
        builder.add(.tap())

        // then the list contains the capture service
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        XCTAssertNotNil(list.first(where: { $0 is TapCaptureService }))
    }

    func test_addViewCaptureService() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a ViewCaptureService
        builder.add(.view())

        // then the list contains the capture service
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        XCTAssertNotNil(list.first(where: { $0 is ViewCaptureService }))
    }
#endif

#if canImport(WebKit)
    func test_addWebViewCaptureService() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a WebViewCaptureService
        let options = WebViewCaptureService.Options(stripQueryParams: true)
        builder.add(.webView(options: options))

        // then the list contains the capture service
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        let service = list[0] as! WebViewCaptureService
        XCTAssert(service.options.stripQueryParams)
    }
#endif

    func test_addLowMemoryWarningCaptureService() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a LowMemoryWarningCaptureService
        builder.add(.lowMemoryWarning())

        // then the list contains the capture service
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        XCTAssertNotNil(list.first(where: { $0 is LowMemoryWarningCaptureService }))
    }

    func test_addLowPowerModeCaptureService() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a LowPowerModeCaptureService
        builder.add(.lowPowerMode())

        // then the list contains the capture service
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        XCTAssertNotNil(list.first(where: { $0 is LowPowerModeCaptureService }))
    }

    func test_addPushNotificationCaptureService() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a PushNotificationCaptureService
        let options = PushNotificationCaptureService.Options(captureData: true)
        builder.add(.pushNotification(options: options))

        // then the list contains the capture service
        let list = builder.build()

        XCTAssertEqual(list.count, 1)
        let service = list[0] as! PushNotificationCaptureService
        XCTAssert(service.options.captureData)
    }

    func test_add_returnValue() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding a service
        let builder2 = builder.add(.lowMemoryWarning())

        // then the builder is returned
        XCTAssert(builder == builder2)
    }

    func test_remove_returnValue() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when removing a service
        let builder2 = builder.remove(ofType: LowMemoryWarningCaptureService.self)

        // then the builder is returned
        XCTAssert(builder == builder2)
    }

    func test_addDefaults_returnValue() throws {
        // given a builder
        let builder = CaptureServiceBuilder()

        // when adding the default services
        let builder2 = builder.addDefaults()

        // then the builder is returned
        XCTAssert(builder == builder2)
    }
}

// swiftlint:enable force_cast
