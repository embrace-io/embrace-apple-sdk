//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension String {
    public var isUUID: Bool {
        return UUID(uuidString: self) != nil
    }
}
