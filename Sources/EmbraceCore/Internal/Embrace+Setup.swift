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

        let baseUrl = EMBDevice.isDebuggerAttached ? endpoints.developmentBaseURL : endpoints.baseURL
        guard let spansURL = URL.spansEndpoint(basePath: baseUrl),
              let logsURL = URL.logsEndpoint(basePath: baseUrl) else {
            Embrace.logger.error("Failed to initialize endpoints!")
            return nil
        }

        let uploadEndpoints = EmbraceUpload.EndpointOptions(spansURL: spansURL, logsURL: logsURL)

        // cache
        guard let cacheUrl = EmbraceFileSystem.uploadsDirectoryPath(
            partitionIdentifier: appId,
            appGroupId: options.appGroupId
        ),
              let cache = EmbraceUpload.CacheOptions(cacheBaseUrl: cacheUrl)
        else {
            Embrace.logger.error("Failed to initialize upload cache!")
            return nil
        }

        // metadata
        let metadata = EmbraceUpload.MetadataOptions(
            apiKey: appId,
            userAgent: EmbraceMeta.userAgent,
            deviceId: deviceId.filter { c in c.isHexDigit }
        )

        do {
            let options = EmbraceUpload.Options(endpoints: uploadEndpoints, cache: cache, metadata: metadata)
            let queue = DispatchQueue(label: "com.embrace.upload", attributes: .concurrent)

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
