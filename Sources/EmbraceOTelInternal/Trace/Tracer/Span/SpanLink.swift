//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetryApi
import OpenTelemetrySdk

public protocol SpanLink {
    var context: SpanContext { get }
    var attributes: [String: AttributeValue] { get }
}

extension SpanData.Link: SpanLink {}
