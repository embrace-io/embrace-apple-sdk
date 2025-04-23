//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal

extension MetricKitCrashCaptureService {
    final class Options: NSObject {
        let provider: MetricKitCrashPayloadProvider?
        let metadataFetcher: EmbraceStorageMetadataFetcher?
        let signals: [Int]

        init(
            provider: MetricKitCrashPayloadProvider?,
            metadataFetcher: EmbraceStorageMetadataFetcher?,
            signals: [Int]
        ) {
            self.provider = provider
            self.metadataFetcher = metadataFetcher
            self.signals = signals
        }

        convenience override init() {
            self.init(
                provider: Embrace.client?.metricKit,
                metadataFetcher: Embrace.client?.storage,
                signals: [ 9 ] // SIGKILL
            )
        }
    }
}
