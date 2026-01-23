//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

/// Class used to set custom Processors when initializing the Embrace SDK.
@objc(EMBOpenTelemetryProcessor)
public class OpenTelemetryProcessor: NSObject {

    public let processor: SpanProcessor
    public let logProcessor: LogRecordProcessor?

    public init(processor: SpanProcessor, logProcessor: LogRecordProcessor? = nil) {
        self.processor = processor
        self.logProcessor = logProcessor
    }
}
