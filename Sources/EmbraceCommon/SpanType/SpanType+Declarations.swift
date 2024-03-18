//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

// MARK: - Primary categories
extension SpanType {
    public static let performance = SpanType(primary: .performance)
    public static let ux = SpanType(primary: .ux)
    public static let system = SpanType(primary: .system)
}

// MARK: - Performance
extension SpanType {

    // File Operations
    public static let fileIO = SpanType(performance: "file.io")
    public static let fileRead = SpanType(performance: "file.read")
    public static let fileWrite = SpanType(performance: "file.write")

    // Database Operations
    public static let sqlSelect = SpanType(performance: "sql.select")
    public static let sqlUpdate = SpanType(performance: "sql.update")
    public static let sqlDelete = SpanType(performance: "sql.delete")
    public static let sqlVacuum = SpanType(performance: "sql.vacuum")

    //  Network types
    public static let networkHTTP = SpanType(performance: "network_request")

}

// MARK: - UX
extension SpanType {
    public static let view = SpanType(ux: "view")
    public static let inputTap = SpanType(ux: "tap")
}

// MARK: - System
extension SpanType {
    public static let lowPower = SpanType(system: "low_power")
}

// MARK: - Embrace Specific
extension SpanType {
    public static let session = SpanType(ux: "session")
}
