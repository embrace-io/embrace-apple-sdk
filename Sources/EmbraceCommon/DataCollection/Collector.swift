//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public protocol Collector {
    /// Called when the SDK starts. Use to
    func start()

    /// 
    func stop()
}

@objc public protocol InstalledCollector: Collector {

    func install(context: CollectorContext)

    func uninstall()
}
