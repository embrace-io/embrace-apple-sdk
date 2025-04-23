//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal

extension Embrace: EmbraceMetricKitStateProvider {
    public var isMetricKitEnabled: Bool {
        return config?.isMetrickKitEnabled ?? true
    }
}
