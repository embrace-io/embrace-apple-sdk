//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol FilePathProvider {
    func fileURL(for scope: String, name: String) -> URL?

    func directoryURL(for scope: String) -> URL?
}
