//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public enum StorageMechanism {
    case inMemory(name: String)
    case onDisk(name: String, baseURL: URL)
}

extension StorageMechanism {

    /// Name identifier
    public var name: String {
        switch self {
        case .onDisk(let name, _): return name
        case .inMemory(let name): return name
        }
    }

    /// URL pointing to the folder where the storage will be saved
    public var baseUrl: URL? {
        switch self {
        case .onDisk(_, let url):
            return url

        default: return nil
        }
    }

    /// URL pointing to the folder where the storage will be saved
    public var fileName: String? {
        switch self {
        case .onDisk(let name, _):
            return name + ".sqlite"

        default: return nil
        }
    }

    /// URL to the storage file
    public var fileURL: URL? {
        switch self {
        case .onDisk(let name, let url):
            return url.appendingPathComponent(name + ".sqlite")

        default: return nil
        }
    }
}
