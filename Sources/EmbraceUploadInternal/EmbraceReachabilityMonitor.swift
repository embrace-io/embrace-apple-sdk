//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation
import Network

final class EmbraceReachabilityMonitor: @unchecked Sendable {
    private let queue: DispatchQueue
    private let monitor: NWPathMonitor
    @ThreadSafe private var wasConnected: Bool = true

    @ThreadSafe var onConnectionRegained: (() -> Void)?

    init(queue: DispatchQueue) {
        self.queue = queue
        self.monitor = NWPathMonitor()

        self.monitor.pathUpdateHandler = { [weak self] path in
            self?.update(connected: path.status == .satisfied)
        }
    }

    func start() {
        monitor.start(queue: self.queue)
    }

    private func update(connected: Bool) {
        if !wasConnected && connected {
            onConnectionRegained?()
        }

        wasConnected = connected
    }
}
