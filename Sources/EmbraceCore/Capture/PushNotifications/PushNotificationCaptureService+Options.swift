//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension PushNotificationCaptureService {
    /// Class used to setup a WebViewCaptureService.
    @objc(EMBPushNotificationCaptureServiceOptions)
    public final class Options: NSObject {
        /// Defines wether or not the Embrace SDK should capture the data from the push notifications
        @objc public let captureData: Bool

        @objc public init(captureData: Bool) {
            self.captureData = captureData
        }

        @objc public convenience override init() {
            self.init(captureData: false)
        }
    }
}
