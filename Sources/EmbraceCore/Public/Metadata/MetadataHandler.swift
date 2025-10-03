//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceSemantics
    import EmbraceCommonInternal
    import EmbraceStorageInternal
    import EmbraceCoreDataInternal
#endif

public enum MetadataLifespan: Int {
    /// The resource will be removed when the session ends.
    case session
    /// The resource will be removed when the process ends
    case process

    /// The resource will be removed when the app is uninstalled.
    case permanent
}

/// Class used to generate resources, properties and persona tags to be included in sessions and logs.
public class MetadataHandler {

    static let maxKeyLength = 128
    static let maxValueLength = 1024

    weak var storage: EmbraceStorage?
    weak var sessionController: SessionControllable?

    internal let synchronizationQueue: DispatchableQueue

    init(
        storage: EmbraceStorage?,
        sessionController: SessionControllable?,
        syncronizationQueue: DispatchableQueue = .with(label: "com.embrace.metadataHandler")
    ) {
        self.storage = storage
        self.sessionController = sessionController
        self.synchronizationQueue = syncronizationQueue
    }

    func addCriticalResource(key: String, value: String) {
        storage?.addCriticalResources([key: value], processId: ProcessIdentifier.current)
    }

    /// Adds a property with the given key, value and lifespan.
    /// If there are 2 properties with the same key but different lifespans, the one with a shorter lifespan will be used.
    /// - Parameters:
    ///   - key: The key of the property to add. Can not be longer than 128 characters.
    ///   - value: The value of the property to add. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the property to add.
    /// - Throws: `MetadataError.invalidKey` if the key is longer than 128 characters.
    /// - Throws: `MetadataError.invalidSession` if a property with a `.session` lifespan is added when there's no active session.
    public func addProperty(key: String, value: String, lifespan: MetadataLifespan = .session) throws {
        try addMetadata(key: key, value: value, type: .customProperty, lifespan: lifespan)
    }

    func addMetadata(key: String, value: String, type: MetadataRecordType, lifespan: MetadataLifespan) throws {
        guard let storage = storage else {
            return
        }

        // validate key
        guard key.count <= Self.maxKeyLength else {
            throw MetadataError.invalidKey("The key length can not be greater than \(Self.maxKeyLength)")
        }

        let lifespanContext = try currentContext(for: lifespan.recordLifespan)

        synchronizationQueue.async {
            let record = storage.addMetadata(
                key: key,
                value: self.validateValue(value),
                type: type,
                lifespan: lifespan.recordLifespan,
                lifespanId: lifespanContext
            )

            if record == nil {
                let limit =
                    type == .customProperty ? storage.options.customPropertiesLimit : storage.options.resourcesLimit
                Embrace.logger.warning("The limit for this type \(type.rawValue) of metadata was reached! (\(limit))")
            }
        }
    }

    /// Updates the value of a resource for a given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the resource to update.
    ///   - value: The value of the resource to update. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the resource to update.
    public func updateResource(key: String, value: String, lifespan: MetadataLifespan = .session) throws {
        try update(key: key, value: value, type: .resource, lifespan: lifespan)
    }

    /// Updates the value of a property for a given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the property to update.
    ///   - value: The value of the property to update. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the property to update.
    public func updateProperty(key: String, value: String, lifespan: MetadataLifespan = .session) throws {
        try update(key: key, value: value, type: .customProperty, lifespan: lifespan)
    }

    private func update(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataLifespan = .session
    ) throws {
        let lifespanId = try currentContext(for: lifespan.recordLifespan)
        synchronizationQueue.async {
            self.storage?.updateMetadata(
                key: key,
                value: self.validateValue(value),
                type: type,
                lifespan: lifespan.recordLifespan,
                lifespanId: lifespanId
            )
        }
    }

    /// Removes the resource for the given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the resource to remove.
    ///   - lifespan: The lifespan of the resource to remove.
    public func removeResource(key: String, lifespan: MetadataLifespan = .session) throws {
        try remove(key: key, type: .resource, lifespan: lifespan)
    }

    /// Removes the property for the given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the property to remove.
    ///   - lifespan: The lifespan of the property to remove.
    public func removeProperty(key: String, lifespan: MetadataLifespan = .session) throws {
        try remove(key: key, type: .customProperty, lifespan: lifespan)
    }

    /// Removes the metadata for the given key, type and lifespan.
    /// - Parameters:
    ///  - key: The key of the metadata to remove.
    ///  - type: The type of the metadata to remove.
    ///  - lifespan: The lifespan of the metadata to remove.
    ///
    ///  - Throws: `MetadataError.invalidSession` if a metadata with a `.session` lifespan is removed when there's no active session.
    func remove(key: String, type: MetadataRecordType, lifespan: MetadataLifespan = .session) throws {
        let lifespanId = try currentContext(for: lifespan.recordLifespan)
        synchronizationQueue.async {
            self.storage?.removeMetadata(
                key: key,
                type: type,
                lifespan: lifespan.recordLifespan,
                lifespanId: lifespanId
            )
        }
    }

    /// Removes all resources for the given lifespans. If no lifespans are passed, all resources are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllResources(lifespans: [MetadataLifespan] = [.permanent, .process, .session]) {
        removeAll(type: .resource, lifespans: lifespans)
    }

    /// Removes all properties for the given lifespans. If no lifespans are passed, all properties are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllProperties(lifespans: [MetadataLifespan]) {
        removeAll(type: .customProperty, lifespans: lifespans)
    }

    func removeAll(type: MetadataRecordType, lifespans: [MetadataLifespan]) {
        synchronizationQueue.async {
            self.storage?.removeAllMetadata(
                type: type,
                lifespans: lifespans.map { $0.recordLifespan }
            )
        }
    }
}

extension MetadataHandler {
    private func validateValue(_ value: String) -> String {
        if value.count <= Self.maxValueLength {
            return value
        }

        let range = value.startIndex...value.index(value.startIndex, offsetBy: Self.maxValueLength - 4)
        return String(value[range]) + "..."
    }
}

extension MetadataHandler {
    private func currentContext(for lifespan: MetadataRecordLifespan) throws -> String {
        if lifespan == .session {
            guard let sessionId = sessionController?.currentSession?.id.stringValue else {
                throw MetadataError.invalidSession("Can't add a session property if there's no active session!")
            }
            return sessionId
        } else if lifespan == .process {
            return ProcessIdentifier.current.stringValue
        } else {
            // permanent
            return MetadataRecord.lifespanIdForPermanent
        }
    }
}

extension MetadataLifespan {
    var recordLifespan: MetadataRecordLifespan {
        switch self {
        case .session: return .session
        case .process: return .process
        case .permanent: return .permanent
        }
    }
}
