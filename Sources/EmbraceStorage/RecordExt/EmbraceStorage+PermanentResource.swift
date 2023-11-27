//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

extension EmbraceStorage {

    public func fetchPermanentResource(key: String) throws -> ResourceRecord? {
         try dbQueue.read { db in
            try query(keys: [key])
                .fetchOne(db)
        }
    }

    public func fetchPermanentResources(keys: [String]) throws -> [ResourceRecord] {
         try dbQueue.read { db in
            try query(keys: keys)
                .fetchAll(db)
        }
    }

    public func removePermanentResources(keys: [String]) throws {
        _ = try dbQueue.write { db in
            try query(keys: keys)
                .deleteAll(db)
        }
    }

    private func query(keys: [String]) -> QueryInterfaceRequest<ResourceRecord> {
        let arguments = StatementArguments(keys)
        return ResourceRecord
            .filter(Column("resource_type") == ResourceType.permanent.rawValue)
            .filter(
                sql: "key IN (\(databaseQuestionMarks(count: keys.count)))",
                arguments: arguments
            )
    }

}
