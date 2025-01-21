//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

extension Embrace: EmbraceSDKStateProvider {
    public var isEnabled: Bool {
        return isSDKEnabled
    }
}
