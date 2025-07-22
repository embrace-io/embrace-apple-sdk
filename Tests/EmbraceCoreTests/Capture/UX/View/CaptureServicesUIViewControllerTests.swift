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

        func test_buildChildSpan_noService() {
            // given capture services without a ViewCaptureService
            let captureServices = CaptureServices(config: enabledConfig, services: [], context: context)
            let vc = MockViewController()

            // when calling buildChildSpan it throws ViewCaptureServiceError.serviceNotFound
            XCTAssertThrowsError(try captureServices.buildChildSpan(for: vc, name: "test")) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -1)
            }
        }

        func test_buildChildSpan_instrumentationDisabled() {
            // given capture services with a ViewCaptureService with disabled instrumentation
            let service = ViewCaptureService(options: disabledOptions)
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling buildChildSpan it throws ViewCaptureServiceError.firstRenderInstrumentationDisabled
            XCTAssertThrowsError(try captureServices.buildChildSpan(for: vc, name: "test")) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -2)
            }
        }

        func test_buildChildSpan_remoteConfigDisabled() {
            // given capture services with a ViewCaptureService with disabled instrumentation via remote config
            let service = ViewCaptureService(options: enabledOptions)
            let captureServices = CaptureServices(config: disabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling buildChildSpan it throws ViewCaptureServiceError.firstRenderInstrumentationDisabled
            XCTAssertThrowsError(try captureServices.buildChildSpan(for: vc, name: "test")) { error in
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
            XCTAssertThrowsError(try captureServices.buildChildSpan(for: vc, name: "test")) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -3)
            }
        }

        func test_buildChildSpan() throws {
            // given capture services with a ViewCaptureService with an active span
            let handler = MockUIViewControllerHandler()
            let service = ViewCaptureService(options: enabledOptions, handler: handler, lock: NSLock())
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            let otel = MockEmbraceOpenTelemetry()
            service.install(otel: otel)
            service.start()

            let parent = otel.buildSpan(name: "test", type: .viewLoad, attributes: [:]).startSpan()
            handler.parentSpan = parent

            // when calling buildChildSpan
            _ = try captureServices.buildChildSpan(for: vc, name: "child")!.startSpan()

            // then the span is created under the right parent
            let spanData = otel.spanProcessor.startedSpans.first(where: { $0.name == "child" })
            XCTAssertNotNil(spanData)
            XCTAssertEqual(spanData!.parentSpanId, parent.context.spanId)
        }

        func test_recordCompletedChildSpan_noService() {
            // given capture services without a ViewCaptureService
            let captureServices = CaptureServices(config: enabledConfig, services: [], context: context)
            let vc = MockViewController()

            // when calling recordCompletedChildSpan it throws ViewCaptureServiceError.serviceNotFound
            XCTAssertThrowsError(
                try captureServices.recordCompletedChildSpan(for: vc, name: "test", startTime: Date(), endTime: Date())
            ) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -1)
            }
        }

        func test_recordCompletedChildSpan_instrumentationDisabled() {
            // given capture services with a ViewCaptureService with disabled instrumentation
            let service = ViewCaptureService(options: disabledOptions)
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling recordCompletedChildSpan it throws ViewCaptureServiceError.firstRenderInstrumentationDisabled
            XCTAssertThrowsError(
                try captureServices.recordCompletedChildSpan(for: vc, name: "test", startTime: Date(), endTime: Date())
            ) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -2)
            }
        }

        func test_recordCompletedChildSpan_noParentSpan() {
            // given capture services with a ViewCaptureService with no active parent span
            let service = ViewCaptureService(options: enabledOptions)
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            // when calling recordCompletedChildSpan it throws ViewCaptureServiceError.parentSpanNotFound
            XCTAssertThrowsError(
                try captureServices.recordCompletedChildSpan(for: vc, name: "test", startTime: Date(), endTime: Date())
            ) { error in
                XCTAssert(error is ViewCaptureServiceError)
                XCTAssertEqual((error as! ViewCaptureServiceError).errorCode, -3)
            }
        }

        func recordCompletedChildSpan() throws {
            // given capture services with a ViewCaptureService with an active span
            let handler = MockUIViewControllerHandler()
            let service = ViewCaptureService(options: enabledOptions, handler: handler, lock: NSLock())
            let captureServices = CaptureServices(config: enabledConfig, services: [service], context: context)
            let vc = MockViewController()

            let otel = MockEmbraceOpenTelemetry()
            service.install(otel: otel)
            service.start()

            let parent = otel.buildSpan(name: "test", type: .viewLoad, attributes: [:]).startSpan()
            handler.parentSpan = parent

            // when calling recordCompletedChildSpan
            try captureServices.recordCompletedChildSpan(for: vc, name: "child", startTime: Date(), endTime: Date())

            // then the span is created under the right parent
            let spanData = otel.spanProcessor.endedSpans.first(where: { $0.name == "child" })
            XCTAssertNotNil(spanData)
            XCTAssertEqual(spanData!.parentSpanId, parent.context.spanId)
        }
    }

#endif
