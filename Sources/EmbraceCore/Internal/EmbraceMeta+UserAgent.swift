//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension EmbraceMeta {
    static var userAgent: String { "Embrace/i/\(sdkVersion)" }
}
