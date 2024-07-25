//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

/// Class used to set custom Exporters when initializing the Embrace SDK.
@objc(EMBOpenTelemetryExport)
public class OpenTelemetryExport: NSObject {

    public let spanExporter: SpanExporter?
    public let logExporter: LogRecordExporter?

    public init(spanExporter: SpanExporter? = nil, logExporter: LogRecordExporter? = nil) {
        self.spanExporter = spanExporter
        self.logExporter = logExporter
    }
}
