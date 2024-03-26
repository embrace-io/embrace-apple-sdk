//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

class SwiftDemangler {
    static let prefixes = ["_T", "$S", "_$S", "$s", "_$s"]

    static func shouldDemangleClassName(_ name: String) -> Bool {
        if prefixes.contains(where: name.hasPrefix) {
            return true
        }

        return false
    }

    static func demangleClassName(_ className: String) -> String {
        if shouldDemangleClassName(className) {
            // TODO: implement demangler from KSCrash.
        }
        return className
    }
}
