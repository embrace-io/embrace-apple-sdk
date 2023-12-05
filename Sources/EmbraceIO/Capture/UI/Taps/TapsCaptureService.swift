//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
#if canImport(UIKit)
import UIKit
import EmbraceCommon

final class TapsCaptureService: SwizzleCaptureService {
    private static var listening = false
    private static var handler: TapCaptureServiceHandlerType?
    private static var installed = false

    required init() {
        if TapsCaptureService.handler == nil {
            TapsCaptureService.handler = TapCaptureServiceHandler()
        }
    }

    convenience init(handler: TapCaptureServiceHandlerType? = TapCaptureServiceHandler()) {
        TapsCaptureService.handler = handler
        self.init()
    }

    func install(context: EmbraceCommon.CaptureServiceContext) {
        guard TapsCaptureService.installed == false else { return }

        TapsCaptureService.installed = true

        replace(#selector(UIWindow.sendEvent(_:)), with: #selector(UIWindow.EMBSwizzledSendEvent(_:)), from: UIWindow.self)
    }

    func start() {
        TapsCaptureService.listening = true
    }

    func stop() {
        TapsCaptureService.listening = false
    }

    func uninstall() {
        TapsCaptureService.listening = false
    }

    static func capturedEvent(_ event: UIEvent) {
        guard TapsCaptureService.listening else { return }
        handler?.handleCapturedEvent(event)
    }
}

extension UIWindow {
    @objc func EMBSwizzledSendEvent(_ event: UIEvent) {
        TapsCaptureService.capturedEvent(event)
        self.EMBSwizzledSendEvent(event)
    }
}
#endif
