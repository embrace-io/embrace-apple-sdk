//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

public protocol EmbraceLog {
    var idRaw: String { get }
    var processIdRaw: String { get }
    var severityRaw: Int { get }
    var body: String { get }
    var timestamp: Date { get }

    func allAttributes() -> [EmbraceLogAttribute]
    func attribute(forKey key: String) -> EmbraceLogAttribute?
}

extension EmbraceLog {
    public var processId: ProcessIdentifier? {
        return ProcessIdentifier(string: processIdRaw)
    }

    public var severity: LogSeverity {
        return LogSeverity(rawValue: severityRaw) ?? .info
    }
}
