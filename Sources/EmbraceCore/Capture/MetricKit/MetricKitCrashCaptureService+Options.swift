//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal
import EmbraceCommonInternal

extension MetricKitCrashCaptureService {
    final class Options: NSObject {
        let crashProvider: MetricKitCrashPayloadProvider?
        let metadataFetcher: EmbraceStorageMetadataFetcher?
        let stateProvider: EmbraceMetricKitStateProvider?
        let signals: [Int]

        init(
            crashProvider: MetricKitCrashPayloadProvider?,
            metadataFetcher: EmbraceStorageMetadataFetcher?,
            stateProvider: EmbraceMetricKitStateProvider?,
            signals: [Int]
        ) {
            self.crashProvider = crashProvider
            self.metadataFetcher = metadataFetcher
            self.stateProvider = stateProvider
            self.signals = signals
        }

        convenience override init() {
            self.init(
                crashProvider: Embrace.client?.metricKit,
                metadataFetcher: Embrace.client?.storage,
                stateProvider: Embrace.client,
                signals: [ 9 ] // SIGKILL
            )
        }
    }
}
