//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData

public protocol EmbraceStorageRecord: NSManagedObject {
    static var entityName: String { get }
}
