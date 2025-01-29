//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommonInternal
import EmbraceStorageInternal
import EmbraceUploadInternal
import EmbraceOTelInternal

class UnsentDataHandler {
    static func sendUnsentData(
        storage: EmbraceStorage?,
        upload: EmbraceUpload?,
        otel: EmbraceOpenTelemetry?,
        logController: LogControllable? = nil,
        currentSessionId: SessionIdentifier? = nil,
        crashReporter: CrashReporter? = nil
    ) {

        guard let storage = storage,
              let upload = upload else {
            return
        }

        // send any logs in storage first before we clean up the resources
        logController?.uploadAllPersistedLogs()

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
        var save = false

        for report in crashReports {

            // link session with crash report if possible
            var session: SessionRecord?

            if let sessionId = SessionIdentifier(string: report.sessionId) {
                session = storage.fetchSession(id: sessionId)
                if let session = session {
                    // update session's end time with the crash report timestamp
                    session.endTime = report.timestamp ?? session.endTime

                    // update crash report id
                    session.crashReportId = report.id.uuidString

                    save = true
                }
            }

            // send crash log
            sendCrashLog(
                report: report,
                reporter: crashReporter,
                session: session,
                storage: storage,
                upload: upload,
                otel: otel
            )
        }

        if save {
            storage.save()
        }

        // send sessions
        sendSessions(
            storage: storage,
            upload: upload,
            currentSessionId: currentSessionId
        )
    }

    static public func sendCrashLog(
        report: CrashReport,
        reporter: CrashReporter?,
        session: SessionRecord?,
        storage: EmbraceStorage?,
        upload: EmbraceUpload?,
        otel: EmbraceOpenTelemetry?
    ) {
        let timestamp = (report.timestamp ?? session?.lastHeartbeatTime) ?? Date()

        // send otel log
        let attributes = createLogCrashAttributes(
            otel: otel,
            storage: storage,
            report: report,
            session: session,
            timestamp: timestamp
        )

        guard let upload = upload else {
            return
        }

        // upload crash log
        do {
            let payload = LogPayloadBuilder.build(
                timestamp: timestamp,
                severity: LogSeverity.fatal,
                body: "",
                attributes: attributes,
                storage: storage,
                sessionId: session?.id
            )
            let payloadData = try JSONEncoder().encode(payload).gzipped()

            upload.uploadLog(id: report.id.uuidString, data: payloadData) { result in
                switch result {
                case .success:
                    // remove crash report
                    // we can remove this immediately because the upload module will cache it until the upload succeeds
                    if let internalId = report.internalId {
                        reporter?.deleteCrashReport(id: internalId)
                    }

                case .failure(let error):
                    Embrace.logger.warning("Error trying to upload crash report \(report.id):\n\(error.localizedDescription)")
                }
            }

        } catch {
            Embrace.logger.warning("Error encoding crash report \(report.id) for session \(String(describing: report.sessionId)):\n" + error.localizedDescription)
        }
    }

    static private func createLogCrashAttributes(
        otel: EmbraceOpenTelemetry?,
        storage: EmbraceStorage?,
        report: CrashReport,
        session: SessionRecord?,
        timestamp: Date
    ) -> [String: String] {

        let attributesBuilder = EmbraceLogAttributesBuilder(
            session: session,
            crashReport: report,
            storage: storage,
            initialAttributes: [:]
        )

        let attributes = attributesBuilder
            .addLogType(.crash)
            .addApplicationProperties()
            .addApplicationState()
            .addSessionIdentifier()
            .addCrashReportProperties()
            .build()

        otel?.log(
            "",
            severity: .fatal,
            type: .crash,
            timestamp: timestamp,
            attributes: attributes,
            stackTraceBehavior: .default
        )

        return attributes
    }

    static private func sendSessions(
        storage: EmbraceStorage,
        upload: EmbraceUpload,
        currentSessionId: SessionIdentifier?
    ) {

        // clean up old spans + close open spans
        cleanOldSpans(storage: storage)
        closeOpenSpans(storage: storage, currentSessionId: currentSessionId)

        // fetch all sessions in the storage
        var sessions: [SessionRecord]
        do {
            sessions = try storage.fetchAll()
        } catch {
            Embrace.logger.warning("Error fetching unsent sessions:\n\(error.localizedDescription)")
            return
        }

        for session in sessions {
            // ignore current session
            if let currentSessionId = currentSessionId,
               currentSessionId == session.id {
                continue
            }

            sendSession(session, storage: storage, upload: upload, performCleanUp: false)
        }

        // remove old metadata
        cleanMetadata(storage: storage, currentSessionId: currentSessionId?.toString)
    }

    static public func sendSession(
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
            Embrace.logger.warning("Error encoding session \(session.idRaw):\n" + error.localizedDescription)
            return
        }

        guard let payloadData = payloadData else {
            return
        }

        // upload session spans
        upload.uploadSpans(id: session.idRaw, data: payloadData) { result in
            switch result {
            case .success:
                do {
                    // remove session from storage
                    // we can remove this immediately because the upload module will cache it until the upload succeeds
                    storage.delete(session)

                    if performCleanUp {
                        cleanOldSpans(storage: storage)
                        cleanMetadata(storage: storage)
                    }

                } catch {
                    Embrace.logger.debug("Error trying to remove session \(session.id):\n\(error.localizedDescription)")
                }

            case .failure(let error):
                Embrace.logger.warning("Error trying to upload session \(session.id):\n\(error.localizedDescription)")
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
            let oldestSession = try storage.fetchOldestSession()
            try storage.cleanUpSpans(date: oldestSession?.startTime)

        } catch {
            Embrace.logger.warning("Error cleaning old spans:\n\(error.localizedDescription)")
        }
    }

    static private func closeOpenSpans(storage: EmbraceStorage, currentSessionId: SessionIdentifier?) {
        do {
            // then we need to close any remaining open spans
            // we use the latest session on storage to determine the `endTime`
            // since we need to have a valid `endTime` for these spans, we default
            // to `Date()` if we don't have a session
            let latestSession = try storage.fetchLatestSession(ignoringCurrentSessionId: currentSessionId)
            let endTime = (latestSession?.endTime ?? latestSession?.lastHeartbeatTime) ?? Date()
            try storage.closeOpenSpans(endTime: endTime)
        } catch {
            Embrace.logger.warning("Error closing open spans:\n\(error.localizedDescription)")
        }
    }

    static private func cleanMetadata(storage: EmbraceStorage, currentSessionId: String? = nil) {
        do {
            let sessionId = currentSessionId ?? Embrace.client?.currentSessionId()
            try storage.cleanMetadata(currentSessionId: sessionId, currentProcessId: ProcessIdentifier.current.hex)
        } catch {
            Embrace.logger.warning("Error cleaning up metadata:\n\(error.localizedDescription)")
        }
    }
}
