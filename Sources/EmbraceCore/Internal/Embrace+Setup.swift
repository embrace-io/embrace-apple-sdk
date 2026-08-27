//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceConfigInternal
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import EmbraceUploadInternal
    import EmbraceConfiguration
    import EmbraceObjCUtilsInternal
#endif

extension Embrace {
    static func createStorage(options: Embrace.Options, configuration: EmbraceConfigurable) throws -> EmbraceStorage {

        let partitionId = options.appId ?? EmbraceFileSystem.defaultPartitionId
        if let storageUrl = EmbraceFileSystem.storageDirectoryURL(
            partitionId: partitionId,
            appGroupId: options.appGroupId
        ) {
            let storageMechanism: StorageMechanism = .onDisk(
                name: "EmbraceStorage",
                baseURL: storageUrl,
                journalMode: configuration.isWalModeEnabled ? .wal : .delete
            )
            let storageOptions = EmbraceStorage.Options(storageMechanism: storageMechanism)
            let storage = try EmbraceStorage(options: storageOptions, logger: Embrace.logger)
            return storage
        } else {
            throw EmbraceSetupError.failedStorageCreation(partitionId: partitionId, appGroupId: options.appGroupId)
        }
    }

    static func createUpload(
        options: Embrace.Options,
        deviceId: String,
        configuration: EmbraceConfigurable
    ) throws -> EmbraceUpload? {
        guard let appId = options.appId else {
            return nil
        }

        // endpoints
        guard let endpoints = options.endpoints else {
            return nil
        }

        guard let spansURL = URL.spansEndpoint(basePath: endpoints.baseURL),
            let logsURL = URL.logsEndpoint(basePath: endpoints.baseURL),
            let attachmentsURL = URL.attachmentsEndpoint(basePath: endpoints.baseURL)
        else {
            Embrace.logger.critical("Failed to initialize endpoints with baseUrl = \(endpoints.baseURL)")
            return nil
        }

        let uploadEndpoints = EmbraceUpload.EndpointOptions(
            spansURL: spansURL,
            logsURL: logsURL,
            attachmentsURL: attachmentsURL
        )

        // cache
        guard
            let cacheUrl = EmbraceFileSystem.uploadsDirectoryPath(
                partitionIdentifier: appId,
                appGroupId: options.appGroupId
            )
        else {
            Embrace.logger.critical("Failed to initialize upload cache!")
            return nil
        }

        let storageMechanism = StorageMechanism.onDisk(
            name: "EmbraceUploadStorage",
            baseURL: cacheUrl,
            journalMode: configuration.isWalModeEnabled ? .wal : .delete
        )

        let cache = EmbraceUpload.CacheOptions(storageMechanism: storageMechanism, resetCache: resetUploadCache)
        resetUploadCache = false

        // metadata
        let metadata = EmbraceUpload.MetadataOptions(
            apiKey: appId,
            userAgent: EmbraceMeta.userAgent,
            deviceId: deviceId.filter { c in c.isHexDigit }
        )

        do {
            let options = EmbraceUpload.Options(endpoints: uploadEndpoints, cache: cache, metadata: metadata)
            let queue = DispatchQueue(label: "com.embrace.upload", qos: .utility)

            return try EmbraceUpload(options: options, logger: Embrace.logger, queue: queue)
        } catch {
            Embrace.logger.critical("Error initializing Embrace Upload: " + error.localizedDescription)
            throw EmbraceSetupError.failedUploadModuleCreation(error.localizedDescription)
        }
    }
    #if os(iOS) || os(tvOS) || os(watchOS)
        static func createSessionLifecycle(controller: SessionControllable) -> SessionLifecycle {
            iOSSessionLifecycle(controller: controller)
        }
    #else
        static func createSessionLifecycle(controller: SessionControllable) -> SessionLifecycle {
            ManualSessionLifecycle(controller: controller)
        }
    #endif

    static let resetUploadCacheKey = "emb.reset-upload-cache"
    static var resetUploadCache: Bool {
        get { UserDefaults.standard.bool(forKey: Embrace.resetUploadCacheKey) }
        set { UserDefaults.standard.set(newValue, forKey: Embrace.resetUploadCacheKey) }
    }
}

/// Extension to handle observability of SDK startup
extension Embrace {

    func createProcessStartSpan() -> Span {
        let builder = buildSpan(name: "emb-process-launch", type: .performance)
            .markAsPrivate()

        if let startTime = ProcessMetadata.startTime {
            builder.setStartTime(time: startTime)
        } else {
            // start time will default to "now" but span will be marked with error
            builder.error(errorCode: .unknown)
        }

        return builder.startSpan()
    }

    func recordSetupSpan(startTime: Date) {
        buildSpan(name: "emb-setup", type: .performance)
            .markAsPrivate()
            .setStartTime(time: startTime)
            .startSpan()
            .end()
    }
}

extension Embrace {
    func cleanUpOldVersionsData() {
        let urls = EmbraceFileSystem.oldVersionsDirectories()

        for url in urls {
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    Embrace.logger.error("Error removing data from an old version!:\n\(error)")
                }
            }
        }
    }
}
