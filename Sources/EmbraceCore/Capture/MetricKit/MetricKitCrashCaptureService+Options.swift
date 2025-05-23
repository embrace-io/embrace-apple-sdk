//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceStorageInternal
import EmbraceCommonInternal
#endif

extension MetricKitCrashCaptureService {
    final class Options: NSObject {
        let crashProvider: MetricKitCrashPayloadProvider?
        let metadataFetcher: EmbraceStorageMetadataFetcher?
        let stateProvider: EmbraceMetricKitStateProvider?

        init(
            crashProvider: MetricKitCrashPayloadProvider?,
            metadataFetcher: EmbraceStorageMetadataFetcher?,
            stateProvider: EmbraceMetricKitStateProvider?
        ) {
            self.crashProvider = crashProvider
            self.metadataFetcher = metadataFetcher
            self.stateProvider = stateProvider
        }

        convenience override init() {
            self.init(
                crashProvider: Embrace.client?.metricKit,
                metadataFetcher: Embrace.client?.storage,
                stateProvider: Embrace.client
            )
        }
    }
}
