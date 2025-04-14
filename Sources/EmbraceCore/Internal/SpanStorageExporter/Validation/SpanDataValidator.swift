//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceOTelInternal
#endif
import OpenTelemetrySdk

protocol SpanDataValidator {
    func validate(data: inout SpanData) -> Bool
}
