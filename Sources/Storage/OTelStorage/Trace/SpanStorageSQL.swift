import Foundation
import GRDB
import OpenTelemetrySdk

public class SpanStorageSQL: SpanStorage {

    private let dbQueue: DatabaseQueue

    public init(fileURL: URL) throws {
        guard fileURL.isFileURL else {
            fatalError("fileURL must have a scheme of file://")
        }

        self.dbQueue = try DatabaseQueue(path: fileURL.path)
    }

    public func createIfNecessary() throws {
        try dbQueue.write { db in

//            ("trace_id", "span_id", "trace_flags", "trace_state", "parent_span_id", "resource", "instrumentation_scope", "name", "kind", "start_time", "attributes", "events", "links", "status", "end_time", "has_remote_parent", "has_ended", "total_recorded_events", "total_recorded_links", "total_attribute_count")
            try db.create(table: SpanData.databaseTableName, options: .ifNotExists) { t in

                // Span Context
                t.column("trace_id", .text).notNull()
                t.column("span_id", .text).notNull()
                t.primaryKey(["trace_id", "span_id"])

                t.column("parent_span_id", .text)
                t.column("trace_flags", .text)
                t.column("trace_state", .text)

                t.column("resource", .text)
                t.column("instrumentation_scope", .text)

                // Span Properties
                t.column("name", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("start_time", .datetime).notNull()
                t.column("end_time", .datetime)
                t.column("attributes", .text)
                t.column("status", .text)
                t.column("has_remote_parent", .boolean)
                t.column("has_ended", .boolean)
                t.column("total_attribute_count", .integer)

                // Span Relations
                t.column("events", .text)
                t.column("links", .text)
                t.column("total_recorded_events", .integer)
                t.column("total_recorded_links", .integer)
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
