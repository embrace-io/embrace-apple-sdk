//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

internal protocol Collector { }

protocol InstalledCollector: Collector {
    func install()
    func start()
    func pause()
    func shutdown()
}

protocol OneTimeCollector: Collector {
    func fire()
}
