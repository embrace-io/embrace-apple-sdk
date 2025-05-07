//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceStorageInternal
import EmbraceObjCUtilsInternal
import EmbraceCommonInternal
import EmbraceSemantics
#endif

class EmbraceLogAttributesBuilder {
    private weak var storage: EmbraceStorageMetadataFetcher?
    private weak var sessionControllable: SessionControllable?
    private var session: EmbraceSession?
    private var crashReport: EmbraceCrashReport?
    private var attributes: [String: String]

    private var currentSession: EmbraceSession? {
        session ?? sessionControllable?.currentSession
    }

    init(storage: EmbraceStorageMetadataFetcher?,
         sessionControllable: SessionControllable,
         initialAttributes: [String: String]) {
        self.storage = storage
        self.sessionControllable = sessionControllable
        self.attributes = initialAttributes
    }

    init(session: EmbraceSession?,
         crashReport: EmbraceCrashReport? = nil,
         storage: EmbraceStorageMetadataFetcher? = nil,
         initialAttributes: [String: String]) {
        self.session = session
        self.storage = storage
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
            attributes[LogSemantics.keyStackTrace] = stackTraceInBase64
        } catch let exception {
            Embrace.logger.error("Couldn't convert stack trace to json string: \(exception.localizedDescription)")
        }
        return self
    }

    /// Makes sure that `emb.type` attribute is not already set in attributes
    /// If not set, will set the `emb.type` to the value
    @discardableResult
    func addLogType(_ logType: LogType) -> Self {
        guard attributes[LogSemantics.keyEmbraceType] == nil else {
            return self
        }
        attributes[LogSemantics.keyEmbraceType] = logType.rawValue
        return self
    }

    @discardableResult
    func addApplicationProperties() -> Self {
        guard let sessionId = currentSession?.id,
              let storage = storage else {
            return self
        }

        let customProperties = storage.fetchCustomPropertiesForSessionId(sessionId)
        customProperties.forEach { record in
            guard UserResourceKey(rawValue: record.key) == nil else {
                // prevent UserResource keys from appearing in properties
                // will be sent in MetadataPayload instead
                return
            }

            let key = String(format: LogSemantics.keyPropertiesPrefix, record.key)
            if attributes[key] == nil {
                attributes[key] = record.value
            }
        }

        return self
    }

    @discardableResult
    func addApplicationState() -> Self {
        guard let state = currentSession?.state,
              attributes[LogSemantics.keyState] == nil else {
            return self
        }
        attributes[LogSemantics.keyState] = state
        return self
    }

    @discardableResult
    func addSessionIdentifier() -> Self {
        guard let sessionId = currentSession?.id,
              attributes[LogSemantics.keySessionId] == nil else {
            return self
        }
        attributes[LogSemantics.keySessionId] = sessionId.toString
        return self
    }

    @discardableResult
    func addCrashReportProperties() -> Self {
        guard let crashReport = crashReport else {
            return self
        }

        attributes[LogSemantics.Crash.keyId] = crashReport.id.withoutHyphen
        attributes[LogSemantics.Crash.keyProvider] = crashReport.provider
        attributes[LogSemantics.Crash.keyPayload] = crashReport.payload

        return self
    }

    func build() -> [String: String] {
        attributes
    }
}
