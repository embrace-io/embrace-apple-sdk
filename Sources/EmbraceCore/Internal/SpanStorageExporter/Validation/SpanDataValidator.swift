//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTel

protocol SpanDataValidator {

    func validate(data: inout SpanData) -> Bool

}
