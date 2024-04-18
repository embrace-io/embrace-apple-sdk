//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage
import EmbraceUpload
import EmbraceOTel
import Gzip

class UnsentDataHandler {
    static func sendUnsentData(
        storage: EmbraceStorage?,
        upload: EmbraceUpload?,
        otel: EmbraceOpenTelemetry?,
        currentSessionId: SessionIdentifier? = nil,
        crashReporter: CrashReporter? = nil
    ) {

        guard let storage = storage,
              let upload = upload else {
            return
        }

        // if we have a crash reporter, we fetch the unsent crash reports first
        // and save their identifiers to the corresponding sessions
        if let crashReporter = crashReporter {
            crashReporter.fetchUnsentCrashReports { reports in
                sendCrashReports(
                    storage: storage,
                    upload: upload,
                    otel: otel,
                    currentSessionId: currentSessionId,
                    crashReporter: crashReporter,
                    crashReports: reports
                )
            }
        } else {
            sendSessions(storage: storage, upload: upload, currentSessionId: currentSessionId)
        }
    }

    static private func sendCrashReports(
        storage: EmbraceStorage,
        upload: EmbraceUpload,
        otel: EmbraceOpenTelemetry?,
        currentSessionId: SessionIdentifier?,
        crashReporter: CrashReporter,
        crashReports: [CrashReport]
    ) {
        // send crash reports
        for report in crashReports {

            // update session
            var session: SessionRecord?

            if let sessionId = SessionIdentifier(string: report.sessionId) {
                do {
                    session = try storage.fetchSession(id: sessionId)
                    if var session = session {
                        // update session's end time with the crash report timestamp
                        session.endTime = report.timestamp ?? session.endTime

                        // update crash report id
                        session.crashReportId = report.id.uuidString

                        try storage.update(record: session)
                    }
                } catch {
                    ConsoleLog.warning("Error updating session \(sessionId) with crashReportId \(report.id)!")
                }
            }

            // send otel log
            if let otel = otel {
                do {
                    let data = try JSONSerialization.data(withJSONObject: report.dictionary)
                    if let body = String(data: data, encoding: String.Encoding.utf8) {
                        logRawCrash(
                            otel: otel,
                            body: body,
                            session: session,
                            timestamp: (report.timestamp ?? session?.endTime) ?? Date()
                        )
                    } else {
                        ConsoleLog.warning("Error serializing raw crash report \(report.id)!")
                    }
                } catch {
                    ConsoleLog.warning("Error serializing raw crash report \(report.id)!")
                }
            }

            // upload crash report
            do {
                let payload = CrashReportPayload(from: report, resourceFetcher: storage)
                let payloadData = try JSONEncoder().encode(payload).gzipped()

                upload.uploadBlob(id: report.id.uuidString, data: payloadData) { result in
                    switch result {
                    case .success:
                        // remove crash report
                        // we can remove this immediately because the upload module will cache it until the upload succeeds
                        crashReporter.deleteCrashReport(id: report.ksCrashId)

                    case .failure(let error): ConsoleLog.warning("Error trying to upload crash report \(report.id):\n\(error.localizedDescription)")
                    }
                }

            } catch {
                ConsoleLog.warning("Error encoding crash report \(report.id) for session \(String(describing: report.sessionId)):\n" + error.localizedDescription)
            }
        }

        // send sessions
        sendSessions(storage: storage, upload: upload, currentSessionId: currentSessionId)
    }

    static private func logRawCrash(
        otel: EmbraceOpenTelemetry,
        body: String,
        session: SessionRecord?,
        timestamp: Date
    ) {

        let attributesBuilder = EmbraceLogAttributesBuilder(
            session: session,
            initialAttributes: [:]
        )

        let finalAttributes = attributesBuilder
            .addLogType(.rawCrash)
            .addApplicationProperties()
            .addSessionIdentifier()
            .build()

        otel.log(
            body,
            severity: .fatal,
            timestamp: timestamp,
            attributes: finalAttributes
        )
    }

    static private func sendSessions(
        storage: EmbraceStorage,
        upload: EmbraceUpload,
        currentSessionId: SessionIdentifier?
    ) {

        // clean up old spans + close open spans
        cleanOldSpans(storage: storage)
        closeOpenSpans(storage: storage)

        // fetch all sessions in the storage
        var sessions: [SessionRecord]
        do {
            sessions = try storage.fetchAll()
        } catch {
            ConsoleLog.warning("Error fetching unsent sessions:\n\(error.localizedDescription)")
            return
        }

        for session in sessions {
            // ignore current session
            if let currentSessionId = currentSessionId,
               currentSessionId == session.id {
                continue
            }

            uploadSession(session, storage: storage, upload: upload, performCleanUp: false)
        }

        // remove old metadata
        cleanMetadata(storage: storage, currentSessionId: currentSessionId?.toString)
    }

    static public func uploadSession(
        _ session: SessionRecord,
        storage: EmbraceStorage,
        upload: EmbraceUpload,
        performCleanUp: Bool = true
    ) {
        // create payload
        let payload = SessionPayloadBuilder.build(for: session, storage: storage)
        var payloadData: Data?

        do {
            payloadData = try JSONEncoder().encode(payload).gzipped()
        } catch {
            ConsoleLog.warning("Error encoding session \(session.id.toString):\n" + error.localizedDescription)
            return
        }

        guard let payloadData = payloadData else {
            return
        }

        // upload session
        upload.uploadSession(id: session.id.toString, data: payloadData) { result in
            switch result {
            case .success:
                do {
                    // remove session from storage
                    // we can remove this immediately because the upload module will cache it until the upload succeeds
                    try storage.delete(record: session)

                    if performCleanUp {
                        cleanOldSpans(storage: storage)
                        cleanMetadata(storage: storage)
                    }

                } catch {
                    ConsoleLog.debug("Error trying to remove session \(session.id):\n\(error.localizedDescription)")
                }

            case .failure(let error):
                ConsoleLog.warning("Error trying to upload session \(session.id):\n\(error.localizedDescription)")
            }
        }
    }

    static private func cleanOldSpans(storage: EmbraceStorage) {
        do {
            // first we delete any span record that is closed and its older
            // than the oldest session we have on storage
            // since spans are only sent when included in a session
            // all of these would never be sent anymore, so they can be safely removed
            // if no session is found, all closed spans can be safely removed as well
            let oldestSession = try storage.fetchOldestSesssion()
            try storage.cleanUpSpans(date: oldestSession?.startTime)

        } catch {
            ConsoleLog.warning("Error cleaning old spans:\n\(error.localizedDescription)")
        }
    }

    static private func closeOpenSpans(storage: EmbraceStorage) {
        do {
            // then we need to close any remaining open spans
            // we use the latest session on storage to determine the `endTime`
            // since we need to have a valid `endTime` for these spans, we default
            // to `Date()` if we don't have a session
            let latestSession = try storage.fetchLatestSesssion()
            let endTime = (latestSession?.endTime ?? latestSession?.lastHeartbeatTime) ?? Date()
            try storage.closeOpenSpans(endTime: endTime)
        } catch {
            ConsoleLog.warning("Error closing open spans:\n\(error.localizedDescription)")
        }
    }

    static private func cleanMetadata(storage: EmbraceStorage, currentSessionId: String? = nil) {
        do {
            let sessionId = currentSessionId ?? Embrace.client?.currentSessionId()
            try storage.cleanMetadata(currentSessionId: sessionId, currentProcessId: ProcessIdentifier.current.hex)
        } catch {
            ConsoleLog.warning("Error cleaning up metadata:\n\(error.localizedDescription)")
        }
    }
}
