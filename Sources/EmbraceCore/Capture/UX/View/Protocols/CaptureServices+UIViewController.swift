//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
import Foundation
import UIKit
import OpenTelemetryApi
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceSemantics
#endif

extension CaptureServices {

    var viewCaptureService: ViewCaptureService? {
        services.value.first(where: { $0 is ViewCaptureService }) as? ViewCaptureService
    }

    var serviceNotFoundError: ViewCaptureServiceError {
        ViewCaptureServiceError.serviceNotFound("No active `ViewCaptureService` found!")
    }

    var firstRenderInstrumentationDisabledError: ViewCaptureServiceError {
        ViewCaptureServiceError
            .firstRenderInstrumentationDisabled("This instrumentation was disabled on the `ViewCaptureService`!")
    }

    var parentSpanNotFoundError: ViewCaptureServiceError {
        ViewCaptureServiceError.parentSpanNotFound("No parent span found!")
    }

    func validateCaptureService() throws -> ViewCaptureService? {
        guard let viewCaptureService = viewCaptureService else {
            throw serviceNotFoundError
        }

        guard viewCaptureService.options.instrumentFirstRender,
              config?.isUiLoadInstrumentationEnabled == true else {
            throw firstRenderInstrumentationDisabledError
        }

        return viewCaptureService
    }

    func onInteractionReady(for vc: UIViewController) throws {
        guard let viewCaptureService = try validateCaptureService() else {
            return
        }

        viewCaptureService.onViewBecameInteractive(vc)
    }

    func buildChildSpan(
        for vc: UIViewController,
        name: String,
        type: SpanType = .viewLoad,
        startTime: Date = Date(),
        attributes: [String: String] = [:]
    ) throws -> SpanBuilder? {
        guard let viewCaptureService = try validateCaptureService() else {
            return nil
        }

        guard let parentSpan = viewCaptureService.parentSpan(for: vc) else {
            throw parentSpanNotFoundError
        }

        guard let builder = viewCaptureService.otel?.buildSpan(
            name: name,
            type: type,
            attributes: attributes,
            autoTerminationCode: nil
        ) else {
            return nil
        }

        builder.setParent(parentSpan)

        return builder
    }

    func recordCompletedChildSpan(
        for vc: UIViewController,
        name: String,
        type: SpanType = .viewLoad,
        startTime: Date,
        endTime: Date,
        attributes: [String: String] = [:]
    ) throws {
        guard let viewCaptureService = try validateCaptureService() else {
            return
        }

        guard let parentSpan = viewCaptureService.parentSpan(for: vc) else {
            throw parentSpanNotFoundError
        }

        guard let builder = viewCaptureService.otel?.buildSpan(
            name: name,
            type: type,
            attributes: attributes,
            autoTerminationCode: nil
        ) else {
            return
        }

        builder.setStartTime(time: startTime)
        builder.setParent(parentSpan)

        let span = builder.startSpan()
        span.end(time: endTime)
    }

    func addAttributesToTrace(
        for viewController: UIViewController,
        attributes: [String: String]
    ) throws {
        guard let viewCaptureService = try validateCaptureService() else {
            return
        }

        guard let parentSpan = viewCaptureService.parentSpan(for: viewController) else {
            throw parentSpanNotFoundError
        }

        attributes.forEach { parentSpan.setAttribute(key: $0.key, value: .string($0.value)) }
    }
}

#endif
