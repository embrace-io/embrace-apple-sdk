//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
#endif

extension Embrace: EmbracePrivateLogger {

    /// Sends a log meant for Embrace's own diagnostics.
    ///
    /// The log is built and uploaded right away instead of going through the regular log pipeline.
    /// This means it is never written to storage, and it is never handed to any log processor or
    /// exporter configured by the user of the SDK. It is marked with the `emb.private` attribute
    /// so the backend can tell it apart from telemetry that belongs to the app.
    ///
    /// - Parameter message: The body of the log.
    package func sendPrivateLog(_ message: String) {
        guard let upload = upload else {
            return
        }

        let id = EmbraceIdentifier.random.stringValue
        let session = sessionController.currentSession

        let attributes =
            EmbraceLogAttributesBuilder(
                storage: storage,
                sessionControllable: sessionController,
                initialAttributes: [
                    LogSemantics.keyId: id,
                    LogSemantics.keyPrivate: "true"
                ]
            )
            .addLogType(.internal)
            .addApplicationProperties()
            .addApplicationState()
            .addSessionIdentifier()
            .build()

        do {
            let payload = LogPayloadBuilder.build(
                timestamp: Date(),
                severity: .error,
                body: message,
                attributes: attributes,
                storage: storage,
                sessionId: session?.id
            )
            let payloadData = try JSONEncoder().encode(payload).gzipped()

            upload.uploadLog(id: id, data: payloadData, payloadTypes: LogType.internal.rawValue) { result in
                if case .failure(let error) = result {
                    Embrace.logger.warning("Error trying to upload private log:\n\(error.localizedDescription)")
                }
            }
        } catch {
            Embrace.logger.warning("Error encoding private log:\n\(error.localizedDescription)")
        }
    }
}
