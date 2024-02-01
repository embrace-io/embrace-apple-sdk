//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

@testable import EmbraceOTel

class DummyEmbraceLogShared: EmbraceLogSharedState {
    var processors: [LogRecordProcessor] = []
    var config: any EmbraceLoggerConfig = RandomConfig()
    var resourceProvider: EmbraceResourceProvider

    init(resourceProvider: EmbraceResourceProvider = DummyEmbraceResourceProvider()) {
        self.resourceProvider = resourceProvider
    }

    func update(_ config: any EmbraceLoggerConfig) { }
}
