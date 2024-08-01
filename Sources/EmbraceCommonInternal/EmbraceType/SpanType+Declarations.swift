//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

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
}
