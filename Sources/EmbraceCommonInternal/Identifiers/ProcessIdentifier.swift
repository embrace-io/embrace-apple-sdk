//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct ProcessIdentifier: Equatable {
    // this used to be a base 16 encoded UInt32,
    // so handling it as a string is currently required
    public let value: String

    public init(uuid value: UUID) {
        self.value = value.uuidString
    }

    public init(string value: String) {
        self.value = value
    }

    public var uuid: UUID? { UUID(uuidString: value) }
}

extension ProcessIdentifier: Codable {}

extension ProcessIdentifier {
    public static var random: ProcessIdentifier {
        ProcessIdentifier(uuid: UUID())
    }
}

extension ProcessIdentifier {
    public static let current: ProcessIdentifier = .random
}

extension ProcessIdentifier: CustomStringConvertible {
    public var description: String { value }
}

@objc(EMBCurrentProcessIdentifier)
public class CurrentProcessIdentifier: NSObject {
    @objc public static let value: String = ProcessIdentifier.current.value
}
