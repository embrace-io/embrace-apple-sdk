//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import Foundation

@testable import EmbraceCore

class MockURLSessionTaskHandlerDataSource: URLSessionTaskHandlerDataSource {
    var state: CaptureServiceState = .uninstalled
    var otel: EmbraceOpenTelemetry?

    var injectTracingHeader = false
    var requestsDataSource: URLSessionRequestsDataSource?
    var ignoredURLs: [String] = []

    var ignoredTaskTypes: [AnyClass] = []
}
