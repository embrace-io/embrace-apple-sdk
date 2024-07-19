//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceOTelInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceObjCUtilsInternal

extension Embrace {
    static func createStorage(options: Embrace.Options) throws -> EmbraceStorage {
        if let storageUrl = EmbraceFileSystem.storageDirectoryURL(
            appId: options.appId,
            appGroupId: options.appGroupId
        ) {
            do {
                let storageOptions = EmbraceStorage.Options(baseUrl: storageUrl, fileName: "db.sqlite")
                let storage = try EmbraceStorage(options: storageOptions, logger: Embrace.logger)
                try storage.performMigration()
                return storage
            } catch {
                throw EmbraceSetupError.failedStorageCreation("Failed to create EmbraceStorage")
            }
        } else {
            throw EmbraceSetupError.failedStorageCreation("Failed to create Storage Directory with appId: '\(options.appId)' appGroupId: '\(options.appGroupId ?? "")'")
        }
    }

    static func createUpload(options: Embrace.Options, deviceId: String) -> EmbraceUpload? {
        // endpoints
        let baseUrl = EMBDevice.isDebuggerAttached ?
            options.endpoints.developmentBaseURL : options.endpoints.baseURL
        guard let spansURL = URL.spansEndpoint(basePath: baseUrl),
              let logsURL = URL.logsEndpoint(basePath: baseUrl) else {
            Embrace.logger.error("Failed to initialize endpoints!")
            return nil
        }

        let endpoints = EmbraceUpload.EndpointOptions(spansURL: spansURL, logsURL: logsURL)

        // cache
        guard let cacheUrl = EmbraceFileSystem.uploadsDirectoryPath(
            appId: options.appId,
            appGroupId: options.appGroupId
        ),
              let cache = EmbraceUpload.CacheOptions(cacheBaseUrl: cacheUrl)
        else {
            Embrace.logger.error("Failed to initialize upload cache!")
            return nil
        }

        // metadata
        let metadata = EmbraceUpload.MetadataOptions(
            apiKey: options.appId,
            userAgent: EmbraceMeta.userAgent,
            deviceId: deviceId.filter { c in c.isHexDigit }
        )

        do {
            let options = EmbraceUpload.Options(endpoints: endpoints, cache: cache, metadata: metadata)
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
