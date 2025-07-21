//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

/// Class used to set custom Processors when initializing the Embrace SDK.
@objc(EMBOpenTelemetryProcessor)
public class OpenTelemetryProcessor: NSObject {

    public let processor: SpanProcessor

    public init(processor: SpanProcessor) {
        self.processor = processor
    }
}
