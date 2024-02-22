//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel

extension Embrace {
    private var otel: EmbraceOTel { .init() }

    public func log(
        _ message: String,
        attributes: [String: String],
        severity: LogSeverity
    ) {
        otel.log(message, attributes: attributes, severity: severity)
    }
}
