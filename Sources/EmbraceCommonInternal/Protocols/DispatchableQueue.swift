//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol DispatchableQueue: AnyObject {
    func async(_ block: @escaping () -> Void)
    func sync(execute block: () -> Void)
}

extension DispatchQueue: DispatchableQueue {
    public func async(_ block: @escaping () -> Void) {
        async(group: nil, execute: block)
    }
}
