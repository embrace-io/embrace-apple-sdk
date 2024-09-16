//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal
import OpenTelemetrySdk

protocol LogDataValidator {

    func validate(data: inout ReadableLogRecord) -> Bool

}
