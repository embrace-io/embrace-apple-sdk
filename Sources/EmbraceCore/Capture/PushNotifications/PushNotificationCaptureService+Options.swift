//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension PushNotificationCaptureService {
    /// Used to setup a `PushNotificationCaptureService`.
    public struct Options {
        /// Defines whether or not the Embrace SDK should capture the data from the push notifications
        public let captureData: Bool

        /// Creates a new `Options` with the given values.
        /// - Parameter captureData: Whether the SDK should capture the data from push notifications.
        public init(captureData: Bool = false) {
            self.captureData = captureData
        }
    }
}
