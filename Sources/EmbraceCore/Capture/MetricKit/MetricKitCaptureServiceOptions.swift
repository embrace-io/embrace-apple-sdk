//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceStorageInternal
    import EmbraceCommonInternal
#endif

struct MetricKitCaptureServiceOptions {
    let payloadProvider: MetricKitPayloadProvider?
    let metadataFetcher: EmbraceStorageMetadataFetcher?
    let stateProvider: EmbraceMetricKitStateProvider?
}
