//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceCoreDataInternal
import CoreData

@objc public enum MetadataLifespan: Int {
    /// The resource will be removed when the session ends.
    case session
    /// The resource will be removed when the process ends
    case process

    /// The resource will be removed when the app is uninstalled.
    case permanent
}

/// Class used to generate resources, properties and persona tags to be included in sessions and logs.
@objc(EMBMetadataHandler)
public class MetadataHandler: NSObject {

    static let maxKeyLength = 128
    static let maxValueLength = 1024

    weak var storage: EmbraceStorage?
    weak var sessionController: SessionControllable?

    let coreData: CoreDataWrapper?

    init(storage: EmbraceStorage?, sessionController: SessionControllable?) {
        self.storage = storage
        self.sessionController = sessionController

        // tmp core data stack
        // only created if the db file is found
        // the entire data gets migrated to the real db and the file is removed
        // that means this should only be executed once
        let coreDataStackName = "EmbraceMetadataTmp"
        if let url = storage?.options.storageMechanism.baseUrl,
           FileManager.default.fileExists(atPath: url.appendingPathComponent(coreDataStackName + ".sqlite").path) {

            let options = CoreDataWrapper.Options(
                storageMechanism: .onDisk(name: coreDataStackName, baseURL: url),
                entities: [MetadataRecordTmp.entityDescription]
            )

            do {
                self.coreData = try CoreDataWrapper(options: options, logger: Embrace.logger)
            } catch {
                Embrace.logger.error("Error setting up temp metadata database!:\n\(error.localizedDescription)")
                self.coreData = nil
            }
        } else {
            self.coreData = nil
        }

        super.init()

        cloneDataBase()
    }

    /// Adds a resource with the given key, value and lifespan.
    /// If there are 2 resources with the same key but different lifespans, the one with a shorter lifespan will be used.
    /// - Parameters:
    ///   - key: The key of the resource to add. Can not be longer than 128 characters.
    ///   - value: The value of the resource to add. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the resource to add.
    /// - Throws: `MetadataError.invalidKey` if the key is longer than 128 characters.
    /// - Throws: `MetadataError.invalidSession` if a resource with a `.session` lifespan is added when there's no active session.
    /// - Throws: `MetadataError.limitReached` if the limit of resources was reached.
    @objc public func addResource(key: String, value: String, lifespan: MetadataLifespan = .session) throws {
        try addMetadata(key: key, value: value, type: .resource, lifespan: lifespan)
    }

    /// Adds a property with the given key, value and lifespan.
    /// If there are 2 properties with the same key but different lifespans, the one with a shorter lifespan will be used.
    /// - Parameters:
    ///   - key: The key of the property to add. Can not be longer than 128 characters.
    ///   - value: The value of the property to add. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the property to add.
    /// - Throws: `MetadataError.invalidKey` if the key is longer than 128 characters.
    /// - Throws: `MetadataError.invalidSession` if a property with a `.session` lifespan is added when there's no active session.
    /// - Throws: `MetadataError.limitReached` if the limit of properties was reached.
    @objc public func addProperty(key: String, value: String, lifespan: MetadataLifespan = .session) throws {
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

        let record = storage.addMetadata(
            key: key,
            value: validateValue(value),
            type: type,
            lifespan: lifespan.recordLifespan,
            lifespanId: lifespanContext
        )

        if record == nil {
            let limit = type == .customProperty ? storage.options.customPropertiesLimit : storage.options.resourcesLimit
            throw MetadataError.limitReached("The limit for this type of metadata was reached! (\(limit))")
        }
    }

    /// Updates the value of a resource for a given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the resource to update.
    ///   - value: The value of the resource to update. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the resource to update.
    @objc public func updateResource(key: String, value: String, lifespan: MetadataLifespan = .session) throws {
        try update(key: key, value: value, type: .resource, lifespan: lifespan)
    }

    /// Updates the value of a property for a given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the property to update.
    ///   - value: The value of the property to update. Will be truncated if its longer than 1024 characters.
    ///   - lifespan: The lifespan of the property to update.
    @objc public func updateProperty(key: String, value: String, lifespan: MetadataLifespan = .session) throws {
        try update(key: key, value: value, type: .customProperty, lifespan: lifespan)
    }

    private func update(
        key: String,
        value: String,
        type: MetadataRecordType,
        lifespan: MetadataLifespan = .session
    ) throws {
        storage?.updateMetadata(
            key: key,
            value: validateValue(value),
            type: type,
            lifespan: lifespan.recordLifespan,
            lifespanId: try currentContext(for: lifespan.recordLifespan)
        )
    }

    /// Removes the resource for the given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the resource to remove.
    ///   - lifespan: The lifespan of the resource to remove.
    @objc public func removeResource(key: String, lifespan: MetadataLifespan = .session) throws {
        try remove(key: key, type: .resource, lifespan: lifespan)
    }

    /// Removes the property for the given key and lifespan.
    /// - Parameters:
    ///   - key: The key of the property to remove.
    ///   - lifespan: The lifespan of the property to remove.
    @objc public func removeProperty(key: String, lifespan: MetadataLifespan = .session) throws {
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
        storage?.removeMetadata(
            key: key,
            type: type,
            lifespan: lifespan.recordLifespan,
            lifespanId: try currentContext(for: lifespan.recordLifespan)
        )
    }

    /// Removes all resources for the given lifespans. If no lifespans are passed, all resources are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllResources(lifespans: [MetadataLifespan] = [.permanent, .process, .session]) throws {
        try removeAll(type: .resource, lifespans: lifespans)
    }

    /// Removes all properties for the given lifespans. If no lifespans are passed, all properties are removed.
    /// - Parameters:
    ///   - lifespans: Array of lifespans.
    public func removeAllProperties(lifespans: [MetadataLifespan]) throws {
        try removeAll(type: .customProperty, lifespans: lifespans)
    }

    func removeAll(type: MetadataRecordType, lifespans: [MetadataLifespan]) throws {
        storage?.removeAllMetadata(
            type: type,
            lifespans: lifespans.map { $0.recordLifespan }
        )
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
            guard let sessionId = sessionController?.currentSessionId?.toString else {
                throw MetadataError.invalidSession("Can't add a session property if there's no active session!")
            }
            return sessionId
        } else if lifespan == .process {
            return ProcessIdentifier.current.hex
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

// tmp core data stack
extension MetadataHandler {
    func cloneDataBase() {
        guard let coreData = coreData,
              let storage = storage else {
            return
        }

        let request = NSFetchRequest<MetadataRecordTmp>(entityName: MetadataRecordTmp.entityName)
        let oldRecords = coreData.fetch(withRequest: request)

        for record in oldRecords {
            guard let type = MetadataRecordType(rawValue: record.type),
                  let lifespan = MetadataRecordLifespan(rawValue: record.lifespan) else {
                continue
            }

            storage.addMetadata(key: record.key, value: record.value, type: type, lifespan: lifespan, lifespanId: record.lifespanId)
        }

        // remove temporary db file
        switch coreData.options.storageMechanism {
        case .onDisk:
            if let url =  coreData.options.storageMechanism.fileURL {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch { }
            }

        default: return
        }
    }
}
