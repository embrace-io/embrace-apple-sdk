//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public typealias Resource = OpenTelemetrySdk.Resource

/// Typealias created to abstract away the `AttributeValue` from `OpenTelemetryApi`,
/// reducing the dependency exposure to dependents.
public typealias ResourceValue = AttributeValue

// This representation of the `Resource` concept was necessary because
// some entities (like `LogReadeableRecord`) needs it.
public protocol EmbraceResource {
    var key: String { get }
    var value: ResourceValue { get }
}
