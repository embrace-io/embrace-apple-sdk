//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class SessionHeartbeat {

    static let defaultInterval: TimeInterval = 5.0

    let queue: DispatchQueue
    let interval: TimeInterval
    var callback: (() -> Void)?

    var timer: DispatchSourceTimer?

    init(queue: DispatchQueue, interval: TimeInterval) {
        self.queue = queue

        if interval > 0 {
            self.interval = interval
        } else {
            self.interval = Self.defaultInterval
        }
    }

    func start() {
        stop()

        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.setEventHandler { [weak self] in
            self?.callback?()
        }

        timer?.schedule(deadline: .now() + interval, repeating: interval)
        timer?.activate()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
