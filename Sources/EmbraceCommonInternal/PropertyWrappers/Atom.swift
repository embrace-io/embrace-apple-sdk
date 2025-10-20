//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@propertyWrapper
@frozen
public struct Atom<Value: EmbraceAtomicType>: Sendable {

    private let storage: EmbraceAtomic<Value>

    public init(wrappedValue: Value) {
        self.storage = EmbraceAtomic(wrappedValue)
    }

    public var wrappedValue: Value {
        get {
            storage.load()
        }
        set {
            storage.store(newValue)
        }
    }

    public var projectedValue: EmbraceAtomic<Value> { storage }
}
