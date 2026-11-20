//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Network

/// A path update reduced to the three facts the connectivity mapping reads, so the mapping stays
/// testable — `NWPath` has no public initializer.
struct NetworkPathSnapshot {
    let isSatisfied: Bool
    let usesWiFi: Bool
    let usesCellular: Bool
}

/// What ``NetworkStateCaptureService`` needs from a path monitor.
///
/// Set ``onPathUpdate`` before calling ``start()``. A monitor is single-use: once cancelled it
/// cannot be started again, matching `NWPathMonitor`.
protocol NetworkPathMonitoring: AnyObject {
    var onPathUpdate: ((NetworkPathSnapshot, Date) -> Void)? { get set }
    func start()
    func cancel()
}

final class NetworkPathMonitor: NetworkPathMonitoring {

    private let monitor = NWPathMonitor()

    /// The monitor's own queue: updates — including the immediate initial one — never touch the
    /// main thread.
    private let queue = DispatchQueue(label: "com.embrace.networkstate.monitor", qos: .utility)

    var onPathUpdate: ((NetworkPathSnapshot, Date) -> Void)?

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let snapshot = NetworkPathSnapshot(
                isSatisfied: path.status == .satisfied,
                usesWiFi: path.usesInterfaceType(.wifi),
                usesCellular: path.usesInterfaceType(.cellular)
            )
            self?.onPathUpdate?(snapshot, Date())
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}
