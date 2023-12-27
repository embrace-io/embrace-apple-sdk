//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

import Foundation

protocol UIWindowSwizzlerProvider {
    func get(usingHandler handler: TapCaptureServiceHandler) -> UIWindowSendEventSwizzler
}

struct DefaultUIWindowSwizzlerProvider: UIWindowSwizzlerProvider {
    func get(usingHandler handler: TapCaptureServiceHandler) -> UIWindowSendEventSwizzler {
        .init(handler: handler)
    }
}
