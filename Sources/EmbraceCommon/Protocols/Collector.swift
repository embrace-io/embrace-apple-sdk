//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public protocol Collector {
    func start()
    func stop()

    func isAvailable() -> Bool
}

@objc public protocol InstalledCollector: Collector {
    func install()
    func shutdown()
}
