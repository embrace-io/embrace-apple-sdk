//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension MetricKitCrashCaptureService {
    final class Options: NSObject {
        let provider: MetricKitCrashPayloadProvider?
        let signals: [Int]

        init(provider: MetricKitCrashPayloadProvider?, signals: [Int]) {
            self.provider = provider
            self.signals = signals
        }

        convenience override init() {
            self.init(provider: Embrace.client?.metricKit, signals: [ 9 ]) // SIGKILL
        }
    }
}
