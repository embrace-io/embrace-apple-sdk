//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import Foundation

public class MockSpanEvent: EmbraceSpanEvent {

    public var name: String
    public var timestamp: Date
    public var attributes: [String : String]
    
    public init(name: String, timestamp: Date, attributes: [String : String]) {
        self.name = name
        self.timestamp = timestamp
        self.attributes = attributes
    }

    public func setAttribute(key: String, value: String?) {
        attributes[key] = value
    }

}
