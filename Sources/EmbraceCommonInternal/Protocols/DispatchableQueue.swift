//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol DispatchableQueue {
    func async(_ block: @escaping () -> Void)
    func sync(execute block: () -> Void)
}

public class DefaultDispatchableQueue: DispatchableQueue {
    private let queue: DispatchQueue

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    public func async(_ block: @escaping () -> Void) {
        queue.async(group: nil, execute: block)
    }

    public func sync(execute block: () -> Void) {
        queue.sync(execute: block)
    }

    public static func with(label: String) -> DispatchableQueue {
        DefaultDispatchableQueue(queue: .init(label: label))
    }
}

public extension DispatchableQueue where Self == DefaultDispatchableQueue {
    static func with(
        label: String,
        qos: DispatchQoS = .unspecified,
        attributes: DispatchQueue.Attributes = []
    ) -> DispatchableQueue {
        DefaultDispatchableQueue(queue: .init(label: label, qos: qos, attributes: attributes))
    }
}
