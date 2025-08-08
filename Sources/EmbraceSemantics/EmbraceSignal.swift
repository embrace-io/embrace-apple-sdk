//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

public protocol EmbraceSignal {
    var attributes: [String: String] { get }
    func setAttribute(key: String, value: String?)
}
