//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

public protocol EmbraceLog {
    var idRaw: String { get set }
    var processIdRaw: String { get set }
    var severityRaw: Int { get set }
    var body: String { get set }
    var timestamp: Date { get set }

    func allAttributes() -> [EmbraceLogAttribute]
    func attribute(forKey key: String) -> EmbraceLogAttribute?
    func setAttributeValue(value: AttributeValue, forKey key: String)
}

public extension EmbraceLog {
    var processId: ProcessIdentifier? {
        return ProcessIdentifier(hex: processIdRaw)
    }

    var severity: LogSeverity {
        return LogSeverity(rawValue: severityRaw) ?? .info
    }
}
