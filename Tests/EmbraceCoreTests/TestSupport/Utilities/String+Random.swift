//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension String {
    static func random() -> String {
        UUID().uuidString
    }

    static func random(length: Int) -> String {
        var randomString = ""

        while randomString.count < length {
            randomString += random()
        }

        return String(randomString.prefix(length))
    }
}
