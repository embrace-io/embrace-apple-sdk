//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCaptureService
import EmbraceCommonInternal
import EmbraceSemantics
import Foundation

@testable import EmbraceCore

class MockURLSessionTaskHandlerDataSource: URLSessionTaskHandlerDataSource {
    var serviceState: CaptureServiceState = .uninstalled
    var otel: EmbraceOTelSignalsHandler?

    var injectTracingHeader = false
    var requestsDataSource: URLSessionRequestsDataSource?
    var ignoredURLs: [String] = []

    var ignoredTaskTypes: [AnyClass] = []
}
