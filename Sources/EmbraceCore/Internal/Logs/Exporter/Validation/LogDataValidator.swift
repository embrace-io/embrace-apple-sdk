//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal

protocol LogDataValidator {

    func validate(data: inout ReadableLogRecord) -> Bool

}
