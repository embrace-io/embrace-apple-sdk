//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import Foundation

public class TemporaryFilepathProvider: FilePathProvider {

    public let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

    public init() {}

    public func fileURL(for scope: String, name: String) -> URL? {
        directoryURL(for: scope)?.appendingPathComponent(name)
    }

    public func directoryURL(for scope: String) -> URL? {
        tmpDirectory.appendingPathComponent(scope)
    }

}
