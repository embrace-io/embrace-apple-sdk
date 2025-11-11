//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation
import Network

final class EmbraceReachabilityMonitor: @unchecked Sendable {
    private let queue: DispatchQueue
    private let monitor: NWPathMonitor
    private let onConnectionRegained: (() -> Void)?
    private var wasConnected: EmbraceAtomic<Bool> = EmbraceAtomic(true)

    init(queue: DispatchQueue, onConnectionRegained: (() -> Void)?) {
        self.queue = queue
        self.monitor = NWPathMonitor()
        self.onConnectionRegained = onConnectionRegained

        self.monitor.pathUpdateHandler = { [weak self] path in
            self?.update(connected: path.status == .satisfied)
        }
    }

    func start() {
        monitor.start(queue: self.queue)
    }

    private func update(connected: Bool) {
        if connected && wasConnected.compareExchange(expected: false, desired: true) {
            onConnectionRegained?()
        }
    }
}
