//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public enum MetadataLifespan: Int {

    /// The property will be removed when the session ends.
    case session

    /// The property will be removed when the process ends
    case process

    /// The property will be removed when the app is uninstalled.
    case permanent
}

public protocol MetadataPropertiesHandling: AnyObject {

    /// Adds, removes or updates a property with a given key and lifespan.
    func setProperty(key: String, value: String?, lifespan: MetadataLifespan) throws
}
