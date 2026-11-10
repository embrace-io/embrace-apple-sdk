//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

@testable import EmbraceCore

/// Lets the state primitive's tests use plain strings as values.
extension String: StateValue {
    public var stateDescription: String { self }
    public var isSystemValue: Bool { false }
}
