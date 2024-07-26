//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - Primary categories
extension LogType {
    public static let system = LogType(primary: .system)
}

// MARK: - System
extension LogType {
    public static let `default` = LogType(system: "log")
    public static let `internal` = LogType(system: "internal")
}
