//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import UIKit

final class TapsCollector: SwizzleCollector {
    private static var listening = false
    private static var handler: TapCollectorHandlerType?
    private static var installed = false

    static var platformAvailability: [EmbracePlatform] = [.iOS]

    required init() {
        if TapsCollector.handler == nil {
            TapsCollector.handler = TapCollectorHandler()
        }
    }

    convenience init(handler: TapCollectorHandlerType? = TapCollectorHandler()) {
        TapsCollector.handler = handler
        self.init()
    }

    func install() {
        guard TapsCollector.installed == false else { return }

        TapsCollector.installed = true

        replace(#selector(UIWindow.sendEvent(_:)), with: #selector(UIWindow.EMBSwizzledSendEvent(_:)), from: UIWindow.self)
    }

    func start() {
        TapsCollector.listening = true
    }

    func pause() {
        TapsCollector.listening = false
    }

    func shutdown() {
        TapsCollector.listening = false
    }

    static func collectedEvent(_ event: UIEvent) {
        guard TapsCollector.listening else { return }
        handler?.handleCollectedEvent(event)
    }
}

extension UIWindow {
    @objc func EMBSwizzledSendEvent(_ event: UIEvent) {
        TapsCollector.collectedEvent(event)
        self.EMBSwizzledSendEvent(event)
    }
}
