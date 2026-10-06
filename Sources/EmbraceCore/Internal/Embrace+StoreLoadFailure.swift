//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import CoreData
import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension Embrace {

    /// Sends an error log reporting that one of the SDK's stores failed to load, so the app's owner can see
    /// why the SDK stopped capturing data on this launch.
    ///
    /// The regular log pipeline can't be used: it persists logs in the storage, which may be the store that
    /// failed, and the SDK is stopping. So, like `sendPrivateLog`, the log is built and uploaded right away,
    /// and it is never handed to any log processor or exporter configured by the user of the SDK.
    ///
    /// The upload goes through the upload cache, so the log can only be sent when the store that failed is the storage.
    func sendStoreLoadFailureLog(store: String, error: Error) {
        guard let upload = upload else {
            return
        }

        let id = EmbraceIdentifier.random.stringValue
        let session = sessionController.currentSession

        var initialAttributes = Self.storeLoadErrorAttributes(store: store, error: error)
        initialAttributes[LogSemantics.keyId] = id

        let attributes =
            EmbraceLogAttributesBuilder(
                storage: storage,
                sessionControllable: sessionController,
                initialAttributes: initialAttributes
            )
            .addLogType(.message)
            .addApplicationState()
            .addSessionIdentifier()
            .addExperiments(experiments.encodedExperiments)
            .addApplicationProperties()
            .build()

        do {
            let payload = LogPayloadBuilder.build(
                timestamp: Date(),
                severity: .error,
                body: "Embrace SDK stopped because its \(store) failed to load",
                attributes: attributes,
                storage: storage,
                sessionId: session?.id,
                processId: ProcessIdentifier.current
            )
            let payloadData = try JSONEncoder().encode(payload).gzipped()

            upload.uploadLog(id: id, data: payloadData, payloadTypes: LogType.message.rawValue) { result in
                if case .failure(let error) = result {
                    Embrace.logger.warning("Error trying to upload store load failure log:\n\(error.localizedDescription)")
                }
            }
        } catch {
            Embrace.logger.warning("Error encoding store load failure log:\n\(error.localizedDescription)")
        }
    }

    /// Attributes describing the load error. The `emb.store_load.*` keys are customer-visible; keep them stable.
    static func storeLoadErrorAttributes(store: String, error: Error) -> [String: String] {
        let nsError = error as NSError
        var attributes = [
            "emb.store_load.store": store,
            "emb.store_load.error_domain": nsError.domain,
            "emb.store_load.error_code": String(nsError.code),
            "emb.store_load.error_message": nsError.localizedDescription
        ]
        if let sqliteCode = nsError.userInfo[NSSQLiteErrorDomain] {
            attributes["emb.store_load.sqlite_error_code"] = "\(sqliteCode)"
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            attributes["emb.store_load.underlying_error"] = "\(underlying.domain) \(underlying.code)"
        }
        return attributes
    }
}
