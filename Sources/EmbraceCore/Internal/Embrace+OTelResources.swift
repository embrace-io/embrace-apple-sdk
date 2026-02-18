//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

extension Embrace {
    func addOtelResources() {
        guard let otelResources else {
            return
        }

        for (key, value) in otelResources {
            try? metadata.addMetadata(key: key, value: value.description, type: .requiredResource, lifespan: .process)
        }
    }
}
