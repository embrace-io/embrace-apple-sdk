//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorageInternal

extension Array where Element == Migration {

    /// Returns a new array containing migrations from this array, maintaining order up to,
    /// but not including, the migration with the given `identifier`.
    func upTo(identifier: String) -> Self {
        let idx = firstIndex { element in
            type(of: element).identifier == identifier
        }

        guard let idx = idx else {
            return []
        }

        return Array(prefix(idx))
    }
}
