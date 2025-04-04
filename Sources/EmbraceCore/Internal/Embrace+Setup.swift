//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceConfigInternal
import EmbraceOTelInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceObjCUtilsInternal
import OpenTelemetryApi

extension Embrace {
    static func createStorage(options: Embrace.Options) throws -> EmbraceStorage {

        let partitionId = options.appId ?? EmbraceFileSystem.defaultPartitionId
        if let storageUrl = EmbraceFileSystem.storageDirectoryURL(
            partitionId: partitionId,
            appGroupId: options.appGroupId
        ) {
            let storageOptions = EmbraceStorage.Options(baseUrl: storageUrl, fileName: "db.sqlite")
            let storage = try EmbraceStorage(options: storageOptions, logger: Embrace.logger)
            try storage.performMigration()
            return storage
        } else {
            throw EmbraceSetupError.failedStorageCreation(partitionId: partitionId, appGroupId: options.appGroupId)
        }
    }

    static func createUpload(options: Embrace.Options, deviceId: String) -> EmbraceUpload? {
        guard let appId = options.appId else {
            return nil
        }

        // endpoints
        guard let endpoints = options.endpoints else {
            return nil
        }

        guard let spansURL = URL.spansEndpoint(basePath: endpoints.baseURL),
              let logsURL = URL.logsEndpoint(basePath: endpoints.baseURL),
              let attachmentsURL = URL.attachmentsEndpoint(basePath: endpoints.baseURL) else {
            Embrace.logger.error("Failed to initialize endpoints!")
            return nil
        }

        let uploadEndpoints = EmbraceUpload.EndpointOptions(
            spansURL: spansURL,
            logsURL: logsURL,
            attachmentsURL: attachmentsURL
        )

        // cache
        guard let cacheUrl = EmbraceFileSystem.uploadsDirectoryPath(
            partitionIdentifier: appId,
            appGroupId: options.appGroupId
        ) else {
            Embrace.logger.error("Failed to initialize upload cache!")
            return nil
        }

        let storageMechanism = StorageMechanism.onDisk(
            name: "EmbraceUploadStorage",
            baseURL: cacheUrl
        )
        let cache = EmbraceUpload.CacheOptions(storageMechanism: storageMechanism)

        // metadata
        let metadata = EmbraceUpload.MetadataOptions(
            apiKey: appId,
            userAgent: EmbraceMeta.userAgent,
            deviceId: deviceId.filter { c in c.isHexDigit }
        )

        do {
            let options = EmbraceUpload.Options(endpoints: uploadEndpoints, cache: cache, metadata: metadata)
            let queue = DispatchQueue(label: "com.embrace.upload", qos: .background, attributes: .concurrent)

            return try EmbraceUpload(options: options, logger: Embrace.logger, queue: queue)
        } catch {
            Embrace.logger.error("Error initializing Embrace Upload: " + error.localizedDescription)
        }

        return nil
    }
#if os(iOS)
    static func createSessionLifecycle(controller: SessionControllable) -> SessionLifecycle {
        iOSSessionLifecycle(controller: controller)
    }
#else
    static func createSessionLifecycle(controller: SessionControllable) -> SessionLifecycle {
        ManualSessionLifecycle(controller: controller)
    }
#endif
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
