//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceStorageInternal
import EmbraceObjCUtilsInternal
import EmbraceCommonInternal

class EmbraceLogAttributesBuilder {
    private weak var storage: EmbraceStorageMetadataFetcher?
    private weak var sessionControllable: SessionControllable?
    private var session: SessionRecord?
    private var crashReport: CrashReport?
    private var attributes: [String: String]

    private var currentSession: SessionRecord? {
        session ?? sessionControllable?.currentSession
    }

    private enum Keys {
        static let type = "emb.type"
        static let state = "emb.state"
        static let sessionId = "emb.session_id"
        static let stackTrace = "emb.stacktrace.ios"
        static let propertiesPrefix = "emb.properties.%@"

        static let crashId = "log.record.uid"
        static let crashProvider = "emb.provider"
        static let crashPayload = "emb.payload"
    }

    init(storage: EmbraceStorageMetadataFetcher,
         sessionControllable: SessionControllable,
         initialAttributes: [String: String]) {
        self.storage = storage
        self.sessionControllable = sessionControllable
        self.attributes = initialAttributes
    }

    init(session: SessionRecord?,
         crashReport: CrashReport? = nil,
         initialAttributes: [String: String]) {
        self.session = session
        self.crashReport = crashReport
        self.attributes = initialAttributes
    }

    @discardableResult
    func addStackTrace(_ stackTrace: [String]) -> Self {
        guard !stackTrace.isEmpty else {
            return self
        }
        let processedStackTrace = EMBStackTraceProccessor.processStackTrace(stackTrace)
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: processedStackTrace, options: [])
            let stackTraceInBase64 = jsonData.base64EncodedString()
            attributes[Keys.stackTrace] = stackTraceInBase64
        } catch let exception {
            Embrace.logger.error("Couldn't convert stack trace to json string: \(exception.localizedDescription)")
        }
        return self
    }

    /// Makes sure that `emb.type` attribute is not already set in attributes
    /// If not set, will set the `emb.type` to the value
    @discardableResult
    func addLogType(_ logType: LogType) -> Self {
        guard attributes[Keys.type] == nil else {
            return self
        }
        attributes[Keys.type] = logType.rawValue
        return self
    }

    @discardableResult
    func addApplicationProperties() -> Self {
        guard let sessionId = currentSession?.id,
              let storage = storage else {
            return self
        }
        if let customProperties = try? storage.fetchCustomPropertiesForSessionId(sessionId) {
            customProperties.forEach { record in
                guard UserResourceKey(rawValue: record.key) == nil else {
                    // prevent UserResource keys from appearing in properties
                    // will be sent in MetadataPayload instead
                    return
                }

                if let value = record.stringValue {
                    let key = String(format: Keys.propertiesPrefix, record.key)
                    attributes[key] = value
                }
            }
        }
        return self
    }

    @discardableResult
    func addApplicationState() -> Self {
        guard let state = currentSession?.state else {
            return self
        }
        attributes[Keys.state] = state
        return self
    }

    @discardableResult
    func addSessionIdentifier() -> Self {
        guard let sessionId = currentSession?.id else {
            return self
        }
        attributes[Keys.sessionId] = sessionId.toString
        return self
    }

    @discardableResult
    func addCrashReportProperties() -> Self {
        guard let crashReport = crashReport else {
            return self
        }

        attributes[Keys.crashId] = crashReport.id.withoutHyphen
        attributes[Keys.crashProvider] = crashReport.provider
        attributes[Keys.crashPayload] = crashReport.payload

        return self
    }

    func build() -> [String: String] {
        attributes
    }
}
