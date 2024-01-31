//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// This provider allows to dependents to decide which resource they should expose or not
/// as an `OpenTelemetryApi.Resource`. Mapping to the actual `Resource` object
/// is being done internally in `EmbraceOTel`.
public protocol EmbraceResourceProvider {
    func getResources() -> [EmbraceResource]
}
