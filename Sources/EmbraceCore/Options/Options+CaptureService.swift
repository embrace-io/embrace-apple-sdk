//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommon

public extension Array where Element == any CaptureService {
    static var automatic: [any CaptureService] {
        return CaptureServiceFactory.platformCaptureServices
    }
}
