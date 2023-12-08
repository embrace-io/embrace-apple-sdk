//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel
import EmbraceStorage
import EmbraceUpload

extension Embrace {
    static func createStorage(options: Embrace.Options) throws -> EmbraceStorage {
        if let storageUrl = EmbraceFileSystem.storageDirectoryURL(
            appId: options.appId,
            appGroupId: options.appGroupId
        ) {
            do {
                let storageOptions = EmbraceStorage.Options(baseUrl: storageUrl, fileName: "db.sqlite")
                return try EmbraceStorage(options: storageOptions)
            } catch {
                // TODO: Create better error
                throw NSError(domain: "EmbraceStorageSetup", code: 1)
            }
        } else {
            // TODO: Create better error
            throw NSError(domain: "EmbraceStorageSetup", code: 2)
        }
    }

    static func createUpload(options: Embrace.Options, deviceId: String) -> EmbraceUpload? {
        // endpoints
        guard let sessionsURL = URL.sessionsEndpoint(basePath: options.endpoints.baseURL),
              let blobsURL = URL.blobsEndpoint(basePath: options.endpoints.baseURL) else {
            ConsoleLog.error("Failed to initialize endpoints!")
            return nil
        }

        let endpoints = EmbraceUpload.EndpointOptions(sessionsURL: sessionsURL, blobsURL: blobsURL)

        // cache
        guard let cacheUrl = EmbraceFileSystem.uploadsDirectoryPath(
            appId: options.appId,
            appGroupId: options.appGroupId
        ),
              let cache = EmbraceUpload.CacheOptions(cacheBaseUrl: cacheUrl)
        else {
            ConsoleLog.error("Failed to initialize upload cache!")
            return nil
        }

        // metadata
        let metadata = EmbraceUpload.MetadataOptions(
            apiKey: options.appId,
            userAgent: EmbraceMeta.userAgent,
            deviceId: deviceId
        )

        do {
            let options = EmbraceUpload.Options(endpoints: endpoints, cache: cache, metadata: metadata)
            let queue = DispatchQueue(label: "com.embrace.upload", attributes: .concurrent)

            return try EmbraceUpload(options: options, queue: queue)
        } catch {
            ConsoleLog.error("Error initializing Embrace Upload: " + error.localizedDescription)
        }

        return nil
    }
#if os(iOS)
    static func createSessionLifecycle(platform: Platform, controller: SessionControllable) -> SessionLifecycle {
        switch platform {
        case .iOS: return iOSSessionLifecycle(controller: controller)
        default: return ManualSessionLifecycle(controller: controller)
        }
    }
//#elseif os(macOS)
#else
    static func createSessionLifecycle(platform: Platform, controller: SessionControllable) -> SessionLifecycle {
        switch platform {
        default: return ManualSessionLifecycle(controller: controller)
        }
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

}
