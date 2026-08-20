//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

extension Embrace: EmbraceSDKStateProvider {
    package var isEnabled: Bool {
        return isSDKEnabled
    }
}
