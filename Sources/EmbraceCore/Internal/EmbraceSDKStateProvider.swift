//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

protocol EmbraceSDKStateProvider: AnyObject {
    var isEnabled: Bool { get}
}

extension Embrace: EmbraceSDKStateProvider {
    var isEnabled: Bool {
        return isSDKEnabled
    }
}
