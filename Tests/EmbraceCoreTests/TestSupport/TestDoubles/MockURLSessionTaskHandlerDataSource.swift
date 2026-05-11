//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceOTelInternal
import Foundation
import OpenTelemetryApi

@testable import EmbraceCore

class MockURLSessionTaskHandlerDataSource: URLSessionTaskHandlerDataSource {
    var serviceState: CaptureServiceState = .uninstalled
    var otel: EmbraceOpenTelemetry?

    var stubbedShouldInjectHeader = false
    var isNSFEligible = false
    var requestsDataSource: URLSessionRequestsDataSource?
    var ignoredURLs: [String] = []

    var ignoredTaskTypes: [AnyClass] = []

    func shouldInjectHeader(for request: URLRequest, span: Span) -> Bool {
        stubbedShouldInjectHeader
    }
}
