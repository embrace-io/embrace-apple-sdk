import Foundation
import GRDB
import OpenTelemetrySdk

public class SpanStorageSQL: SpanStorage {

    private let dbQueue: DatabaseQueue

    public init(fileURL: URL) throws {
        guard fileURL.isFileURL else {
            fatalError("fileURL must have a scheme of file://")
        }

        self.dbQueue = try! DatabaseQueue(path: fileURL.path)
    }

    public func createIfNecessary() throws {
        try dbQueue.write { db in
            try db.create(table: SpanData.databaseTableName, options: .ifNotExists) { t in

                // Span Context
                t.column("trace_id", .text).notNull()
                t.column("span_id", .text).notNull()
                t.primaryKey(["trace_id", "span_id"])

                t.column("parent_span_id", .text)

                // Span Properties
                t.column("name", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("start_time", .datetime).notNull()
                t.column("end_time", .datetime)
                t.column("attributes", .text)

                // Span Status
//                t.column("status", .integer).notNull()
//                t.column("status_description", .text)

                // Bubbled Embrace Attributes
//                t.column("emb_type", .text).notNull()
            }
        }
    }

    public func add(entry: SpanData) throws {
        try add(entries: [entry])
    }

    public func add(entries: [SpanData]) throws {
        try dbQueue.write { db in
            for spanData in entries {
                try spanData.insert(db)
            }
        }
    }

    public func fetchAll() throws -> [SpanData] {
        try dbQueue.read { db in
            return try SpanData.fetchAll(db)
        }
    }

}
