//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceStorage
import EmbraceUpload

class UnsentDataHandler {
    static func sendUnsentData(storage: EmbraceStorage?, upload: EmbraceUpload?, crashReporter: CrashReporter?) {
        guard let storage = storage,
              let upload = upload else {
            return
        }

        // if we have a crash reporter, we fetch the unsent crash reports first
        // and save their identifiers to the corresponding sessions

        // TODO: Check that crash reports are fetched in chronological order!
        if let crashReporter = crashReporter {
            crashReporter.fetchUnsentCrashReports { reports in
                sendCrashReports(storage: storage, upload: upload, crashReporter: crashReporter, crashReports: reports)
            }
        } else {
            sendSessions(storage: storage, upload: upload)
        }
    }

    static private func sendCrashReports(storage: EmbraceStorage, upload: EmbraceUpload, crashReporter: CrashReporter, crashReports: [CrashReport]) {
        // send crash reports
        for report in crashReports {

            // update session
            if let sessionId = report.sessionId {
                do {
                    if var session = try storage.fetchSession(id: sessionId) {
                        // update session's end time with the crash report timestamp
                        session.endTime = report.timestamp ?? session.endTime

                        // update crash report id
                        session.crashReportId = report.id.uuidString

                        try storage.update(record: session)
                    }
                } catch {
                    print("Error updating session \(sessionId) with crashReportId \(report.id)!")
                }
            }

            // upload crash report
            upload.uploadBlob(id: report.id.uuidString, data: report.data) { result in
                switch result {
                case .success: print("Successfully uploaded crash report \(report.id)!")
                case .failure(let error): print("Error trying to upload crash report \(report.id):\n\(error.localizedDescription)")
                }
            }

            // remove crash report
            // we can remove this immediately because the upload module will cache it until the upload succeeds
            crashReporter.deleteCrashReport(id: report.ksCrashId)
        }

        // send sessions
        sendSessions(storage: storage, upload: upload)
    }

    static private func sendSessions(storage: EmbraceStorage, upload: EmbraceUpload) {
        // fetch finished sessions
        do {
            let sessions = try storage.fetchFinishedSessions()

            for session in sessions {
                let data = "test".data(using: .utf8)! // TODO: Build session payload

                // upload session
                upload.uploadSession(id: session.id, data: data) { result in
                    switch result {
                    case .success: print("Successfully uploaded session \(session.id)!")
                    case .failure(let error): print("Error trying to upload session \(session.id):\n\(error.localizedDescription)")
                    }
                }

                // remove session from storage
                // we can remove this immediately because the upload module will cache it until the upload succeeds
                do {
                    try storage.delete(record: session)
                } catch {
                    print("Error trying to remove session \(session.id):\n\(error.localizedDescription)")
                }
            }

        } catch {
            print("Error fetching unsent sessions:\n\(error.localizedDescription)")
        }
    }
}
