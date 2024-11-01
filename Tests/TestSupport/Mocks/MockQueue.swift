//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

public class MockQueue: DispatchableQueue {
    public func async(_ block: @escaping () -> Void) {
        block()
    }

    public func sync(execute block: () -> Void) {
        block()
    }

    public init() {}
}
