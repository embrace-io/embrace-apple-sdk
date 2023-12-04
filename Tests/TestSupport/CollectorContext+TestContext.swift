//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//
    

import Foundation
import EmbraceCommon

extension CollectorContext {
    public static var testContext: CollectorContext {
        CollectorContext(appId: TestConstants.appId, sdkVersion: TestConstants.sdkVersion, filePathProvider: TemporaryFilepathProvider())
    }
}
