//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage

public extension EmbraceStorage {
    static func createInMemoryDb() throws -> EmbraceStorage {
        try .init(options: .init(named: UUID().uuidString))
    }

    static func createInDiskDb() throws -> EmbraceStorage {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
        return try .init(options: .init(baseUrl: url, fileName: "\(UUID().uuidString).sqlite"))
    }
}

public extension EmbraceStorage {
    func teardown() throws {
        try dbQueue.close()
    }
}
