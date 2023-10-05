//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import UIKit

internal protocol Collector {
    static var platformAvailability: [EmbracePlatform] { get }
    init()
}

protocol InstalledCollector: Collector {
    func install()
    func start()
    func pause()
    func shutdown()
}

protocol OneTimeCollector: Collector {
    func fire()
}

protocol SwizzleCollector: InstalledCollector {
    func replace(_ originalSelector: Selector, with newSelector: Selector, from containerClass: AnyClass)
}

extension SwizzleCollector {
    func replace(_ originalSelector: Selector, with newSelector: Selector, from containerClass: AnyClass) {
        if let originalInstance = class_getInstanceMethod(containerClass, originalSelector),
           let newInstance = class_getInstanceMethod(containerClass, newSelector) {
            method_exchangeImplementations(originalInstance, newInstance)
        }
    }
}
