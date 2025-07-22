//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceOTelInternal
#endif

protocol LogDataValidator {

    func validate(data: inout ReadableLogRecord) -> Bool

}
