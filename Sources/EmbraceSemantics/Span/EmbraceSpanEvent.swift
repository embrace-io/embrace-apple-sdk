//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Represents an OTel span event
public protocol EmbraceSpanEvent: EmbraceSignal {
    
    /// Name of the event
    var name: String { get }

    /// Date when the event occured
    var timestamp: Date { get }
}
