//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit) && !os(watchOS)

    import Foundation
    import XCTest
    @testable import EmbraceCore
    import TestSupport
    import EmbraceCommonInternal

    class CaptureServicesUIViewControllerTests: XCTestCase {

        let context = CrashReporterContext(
            appId: nil,
            sdkVersion: TestConstants.sdkVersion,
            filePathProvider: EmbraceFilePathProvider(partitionId: "test", appGroupId: nil),
            notificationCenter: NotificationCenter.default
        )
        let enabledOptions = ViewCaptureService.Options(instrumentVisibility: true, instrumentFirstRender: true)
        let disabledOptions = ViewCaptureService.Options(instrumentVisibility: false, instrumentFirstRender: false)

        let enabledConfig = EditableConfig(isUiLoadInstrumentationEnabled: true)
        let disabledConfig = EditableConfig(isUiLoadInstrumentationEnabled: false)

        func test_onInteractionReady_noService() {
            // given capture services without a ViewCaptureService
            let captureServices = CaptureServices(config: enabledConfig, services: [], context: context)
            let vc = MockViewController()

            // when calling onInteractionReady it throws ViewCaptureServiceError.serviceNotFound
            XCTAssertThrowsError(try captureServices.onInteractionReady(for: vc)) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -1)
            }
        }

        func test_onInteractionReady_instrumentationDisabled() {
            // given capture services with a ViewCaptureService with disabled instrumentation
            let service = ViewCaptureService(options: disabledOptions)
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling onInteractionReady it throws ViewCaptureServiceError.firstRenderInstrumentationDisabled
            XCTAssertThrowsError(try captureServices.onInteractionReady(for: vc)) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -2)
            }
        }

        func test_onInteractionReady_remoteConfigDisabled() {
            // given capture services with a ViewCaptureService with disabled instrumentation via remote config
            let service = ViewCaptureService(options: enabledOptions)
            let captureServices = CaptureServices(config: disabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling onInteractionReady it throws ViewCaptureServiceError.firstRenderInstrumentationDisabled
            XCTAssertThrowsError(try captureServices.onInteractionReady(for: vc)) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -2)
            }
        }

        func test_onInteractionReady() throws {
            // given capture services with a ViewCaptureService
            let handler = MockUIViewControllerHandler()
            let service = ViewCaptureService(options: enabledOptions, handler: handler, lock: NSLock())
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling onInteractionReady
            try captureServices.onInteractionReady(for: vc)

            // then it gets forwarded to the ViewCaptureService
            XCTAssert(handler.onViewBecameInteractiveCalled)
        }

        func test_createChildSpan_noService() {
            // given capture services without a ViewCaptureService
            let captureServices = CaptureServices(config: enabledConfig, services: [], context: context)
            let vc = MockViewController()

            // when calling buildChildSpan it throws ViewCaptureServiceError.serviceNotFound
            XCTAssertThrowsError(try captureServices.createChildSpan(for: vc, name: "test")) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -1)
            }
        }

        func test_createChildSpan_instrumentationDisabled() {
            // given capture services with a ViewCaptureService with disabled instrumentation
            let service = ViewCaptureService(options: disabledOptions)
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling buildChildSpan it throws ViewCaptureServiceError.firstRenderInstrumentationDisabled
            XCTAssertThrowsError(try captureServices.createChildSpan(for: vc, name: "test")) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -2)
            }
        }

        func test_createChildSpan_remoteConfigDisabled() {
            // given capture services with a ViewCaptureService with disabled instrumentation via remote config
            let service = ViewCaptureService(options: enabledOptions)
            let captureServices = CaptureServices(config: disabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling buildChildSpan it throws ViewCaptureServiceError.firstRenderInstrumentationDisabled
            XCTAssertThrowsError(try captureServices.createChildSpan(for: vc, name: "test")) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -2)
            }
        }

        func test_buildChildSpan_noParentSpan() {
            // given capture services with a ViewCaptureService with no active parent span
            let service = ViewCaptureService(options: enabledOptions)
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling buildChildSpan it throws ViewCaptureServiceError.parentSpanNotFound
            XCTAssertThrowsError(try captureServices.createChildSpan(for: vc, name: "test")) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -3)
            }
        }

        func test_createChildSpan() throws {
            // given capture services with a ViewCaptureService with an active span
            let handler = MockUIViewControllerHandler()
            let service = ViewCaptureService(options: enabledOptions, handler: handler, lock: NSLock())
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            let otel = MockOTelSignalsHandler()
            service.install(otel: otel)
            service.start()

            let parent = try! otel.createInternalSpan(name: "test", type: .viewLoad)
            handler.parentSpan = parent

            // when calling buildChildSpan
            _ = try captureServices.createChildSpan(for: vc, name: "child")

            // then the span is created under the right parent
            let spanData = otel.startedSpans.first(where: { $0.name == "child" })
            XCTAssertNotNil(spanData)
            XCTAssertEqual(spanData!.parentSpanId, parent.context.spanId)
        }
    }

#endif
