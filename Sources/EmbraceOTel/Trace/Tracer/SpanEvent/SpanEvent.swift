//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

public protocol SpanEvent {
    var name: String { get }
    var timestamp: Date { get }
    var attributes: [String: AttributeValue] { get }
}
