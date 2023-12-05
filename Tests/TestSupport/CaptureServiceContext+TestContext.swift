//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon

extension CaptureServiceContext {
    public static var testContext: CaptureServiceContext {
        CaptureServiceContext(appId: TestConstants.appId, sdkVersion: TestConstants.sdkVersion, filePathProvider: TemporaryFilepathProvider())
    }
}
