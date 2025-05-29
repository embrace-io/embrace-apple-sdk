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
        let payloadProvider: MetricKitPayloadProvider?
        let metadataFetcher: EmbraceStorageMetadataFetcher?
        let stateProvider: EmbraceMetricKitStateProvider?

        init(
            payloadProvider: MetricKitPayloadProvider?,
            metadataFetcher: EmbraceStorageMetadataFetcher?,
            stateProvider: EmbraceMetricKitStateProvider?
        ) {
            self.payloadProvider = payloadProvider
            self.metadataFetcher = metadataFetcher
            self.stateProvider = stateProvider
        }
    }
}
