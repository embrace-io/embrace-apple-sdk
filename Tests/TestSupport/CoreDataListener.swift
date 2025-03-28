//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import CoreData

public class CoreDataListener {

    public var onInsertedObjects: ((Set<NSManagedObject>) -> Void)?
    public var onUpdatedObjects: ((Set<NSManagedObject>) -> Void)?
    public var onDeletedObjects: ((Set<NSManagedObject>) -> Void)?

    public init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextObjectsDidChange(_:)),
            name: Notification.Name.NSManagedObjectContextObjectsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func contextObjectsDidChange(_ notification: Notification) {

        if let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>, !insertedObjects.isEmpty {
            onInsertedObjects?(insertedObjects)
        }

        if let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            onUpdatedObjects?(updatedObjects)
        }

        if let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletedObjects.isEmpty {
            onDeletedObjects?(deletedObjects)
        }
    }
}
