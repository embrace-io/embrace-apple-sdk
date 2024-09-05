//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public protocol SpanEvent {
    var name: String { get }
    var timestamp: Date { get }
    var attributes: [String: AttributeValue] { get }
}

extension SpanData.Event: SpanEvent { }
