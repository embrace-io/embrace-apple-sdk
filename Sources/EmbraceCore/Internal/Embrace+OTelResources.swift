//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import OpenTelemetrySdk

extension Embrace {
    func addOtelResources() {
        guard let otelResources else {
            return
        }

        for (key, value) in otelResources.attributes {
            try? metadata.addMetadata(key: key, value: value.description, type: .requiredResource, lifespan: .process)
        }
    }
}
