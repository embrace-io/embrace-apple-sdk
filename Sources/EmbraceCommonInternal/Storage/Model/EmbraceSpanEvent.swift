//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol EmbraceSpanEvent {
    var name: String { get }
    var timestamp: Date { get }
    var attributes: [String: String] { get }
}
