//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension String {
    public var isUUID: Bool {
        return UUID(uuidString: self) != nil
    }

    public static func randomSpanId() -> String {
        var id: UInt64 = 0
        repeat {
          id = UInt64.random(in: .min ... .max)
        } while id == 0

        return String(format: "%016llx", id)
    }

    public static func randomTraceId() -> String {
        var idHi: UInt64
        var idLo: UInt64
        repeat {
          idHi = UInt64.random(in: .min ... .max)
          idLo = UInt64.random(in: .min ... .max)
        } while idHi == 0 && idLo == 0

        return String(format: "%016llx%016llx", idHi, idLo)
    }
}
