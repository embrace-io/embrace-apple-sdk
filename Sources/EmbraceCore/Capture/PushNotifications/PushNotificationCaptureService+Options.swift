//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension PushNotificationCaptureService {
    /// Class used to setup a `PushNotificationCaptureService`.
    public struct Options {
        /// Defines wether or not the Embrace SDK should capture the data from the push notifications
        public let captureData: Bool

        public init(captureData: Bool = false) {
            self.captureData = captureData
        }
    }
}
