//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// `SpanEventTypeLimits` manages limits for span events included in the session span.
@objc public class SpanEventTypeLimits: NSObject {
    public let breadcrumb: UInt

    public init(breadcrumb: UInt = 100) {
        self.breadcrumb = breadcrumb
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Self else {
            return false
        }

        return breadcrumb == other.breadcrumb
    }
}
