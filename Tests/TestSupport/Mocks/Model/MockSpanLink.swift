//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import Foundation

public class MockSpanLink: EmbraceSpanLink {

    public var spanId: String
    public var traceId: String
    public var attributes: [String : String]

    public init(spanId: String, traceId: String, attributes: [String : String]) {
        self.spanId = spanId
        self.traceId = traceId
        self.attributes = attributes
    }

    public func setAttribute(key: String, value: String?) {
        attributes[key] = value
    }

}
