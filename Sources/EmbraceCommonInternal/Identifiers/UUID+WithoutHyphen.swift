//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension UUID {

    /// Initialize a UUID from a string that is 32 hexadecimal characters without hyphens
    /// Will defensively attempt to initialize UUID if string contains hyphens
    public init?(withoutHyphen: String) {
        if withoutHyphen.count != 32 {
            // try to initialize with hyphens
            self.init(uuidString: withoutHyphen)
            return
        }

        let uuidString = withoutHyphen.replacingOccurrences(
            of: "(.{8})(.{4})(.{4})(.{4})(.{12})",
            with: "$1-$2-$3-$4-$5",
            options: .regularExpression
        )
        self.init(uuidString: uuidString)
    }

    /// A UUID string without hyphens
    public var withoutHyphen: String {
        return uuidString.replacingOccurrences(of: "-", with: "")
    }
}
