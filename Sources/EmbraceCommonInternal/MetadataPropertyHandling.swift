//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol MetadataPropertiesHandling: AnyObject {

    /// Adds, removes or updates a property with a given key to the process.
    func setProcessProperty(key: String, value: String?) throws

    /// Adds, removes or updates a property with a given key to the session.
    func setSessionProperty(key: String, value: String?) throws
}
