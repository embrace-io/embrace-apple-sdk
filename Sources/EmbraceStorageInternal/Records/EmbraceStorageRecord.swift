//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

public protocol EmbraceStorageRecord: NSManagedObject {
    static var entityName: String { get }
}
