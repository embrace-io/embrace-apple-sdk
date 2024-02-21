//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetrySdk

@testable import EmbraceOTel

class MockEmbraceLogSharedState: EmbraceLogSharedState {
    var processors: [EmbraceLogRecordProcessor]
    var config: any EmbraceLoggerConfig
    var resourceProvider: EmbraceResourceProvider

    init(
        processors: [EmbraceLogRecordProcessor] = [],
        config: any EmbraceLoggerConfig = RandomConfig(),
        resourceProvider: EmbraceResourceProvider = DummyEmbraceResourceProvider()
    ) {
        self.processors = processors
        self.config = config
        self.resourceProvider = resourceProvider
    }

    func update(_ config: any EmbraceLoggerConfig) {
        self.config = config
    }
}
