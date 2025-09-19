//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

public struct EmbraceMetadataType: Equatable, Hashable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}

public protocol EmbraceMetadataProvider: AnyObject {
    var type: EmbraceMetadataType { get }
    func provide() -> [String: String]
}

extension EmbraceMetadataType {
    public static let flushInterval = EmbraceMetadataType("flushInterval")
}

public class FlushIntervalMetadataProvider: EmbraceMetadataProvider {
    public let type = EmbraceMetadataType.flushInterval

    public func provide() -> [String: String] {
        ["flush_interval": "\(Int.random(in: 0...100))"]
    }
}
