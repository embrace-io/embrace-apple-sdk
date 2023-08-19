
import Foundation
import OpenTelemetrySdk
import GRDB


extension SpanData: TableRecord {
    public static let databaseTableName: String = "otel_spans"
}

extension SpanData: FetchableRecord {
    public static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
}

extension SpanData: PersistableRecord {
    public static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
}
