//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Network

class EmbraceReachabilityMonitor {
    private let queue: DispatchQueue
    private let monitor: NWPathMonitor
    private var wasConnected: Bool = true

    var onConnectionRegained: (() -> Void)?

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
