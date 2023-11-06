//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public extension String {
    var isUUID: Bool {
        return UUID(uuidString: self) != nil
    }
}
