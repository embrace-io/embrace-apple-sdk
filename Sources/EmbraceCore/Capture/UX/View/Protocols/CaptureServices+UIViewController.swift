//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if canImport(UIKit) && !os(watchOS)
    import Foundation
    import UIKit
    #if !EMBRACE_COCOAPOD_BUILDING_SDK
        import EmbraceCommonInternal
        import EmbraceSemantics
    #endif

    extension CaptureServices {

        var viewCaptureService: ViewCaptureService? {
            services.first(where: { $0 is ViewCaptureService }) as? ViewCaptureService
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
                config?.isUiLoadInstrumentationEnabled == true
            else {
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

        func createChildSpan(
            for vc: UIViewController,
            name: String,
            type: EmbraceType = .viewLoad,
            startTime: Date = Date(),
            endTime: Date? = nil,
            attributes: EmbraceAttributes = [:]
        ) throws -> EmbraceSpan? {
            guard let viewCaptureService = try validateCaptureService() else {
                return nil
            }

            guard let parentSpan = viewCaptureService.parentSpan(for: vc) else {
                throw parentSpanNotFoundError
            }

            // the name and attributes come from the app, so the span gets the user limits and sanitization
            return try? viewCaptureService.otel?._createSpan(
                name: name,
                parentContext: parentSpan.context,
                type: type,
                status: .unset,
                startTime: startTime,
                endTime: endTime,
                events: [],
                links: [],
                attributes: attributes,
                autoTerminationCode: nil,
                source: .user
            )
        }

        func addAttributesToTrace(
            for viewController: UIViewController,
            attributes: EmbraceAttributes
        ) throws {
            guard let viewCaptureService = try validateCaptureService() else {
                return
            }

            guard let parentSpan = viewCaptureService.parentSpan(for: viewController) else {
                throw parentSpanNotFoundError
            }

            attributes.forEach {
                parentSpan.setAttribute(key: $0.key, value: $0.value)
            }
        }
    }

#endif
