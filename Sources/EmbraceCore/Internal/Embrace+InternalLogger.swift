//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
#endif

extension Embrace {
    package static func setLogLevel(_ logLevel: EmbraceLogLevel) {
        Embrace.logger.level = logLevel
    }
}
