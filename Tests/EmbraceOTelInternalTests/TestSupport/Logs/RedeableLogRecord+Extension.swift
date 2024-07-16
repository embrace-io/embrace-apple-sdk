//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

extension ReadableLogRecord {
    static func log(withTestId testId: String) -> ReadableLogRecord {
        .init(
            resource: .init(),
            instrumentationScopeInfo: .init(),
            timestamp: Date(),
            attributes: ["testId": .string(testId)]
        )
    }

    func getTestId() throws -> String {
        if let testId = attributes["testId"] {
            return testId.description
        }
        throw NSError(domain: "EmbraceTests", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Test Id Not Found"])
    }
}
