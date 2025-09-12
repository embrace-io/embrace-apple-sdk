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
    internal var attributes: [String: String]

    private var currentSession: EmbraceSession? {
        session ?? sessionControllable?.currentSession
    }

    init(
        storage: EmbraceStorageMetadataFetcher?,
        sessionControllable: SessionControllable,
        initialAttributes: [String: String]
    ) {
        self.storage = storage
        self.sessionControllable = sessionControllable
        self.attributes = initialAttributes
    }

    init(
        session: EmbraceSession?,
        crashReport: EmbraceCrashReport? = nil,
        storage: EmbraceStorageMetadataFetcher? = nil,
        initialAttributes: [String: String]
    ) {
        self.session = session
        self.storage = storage
        self.crashReport = crashReport
        self.attributes = initialAttributes
    }

    private func serializeProcessedStackTrace(_ processedStackTrace: [[String: Any]]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: processedStackTrace, options: [.prettyPrinted, .sortedKeys])
            let stackTraceInBase64 = jsonData.base64EncodedString()
            attributes[LogSemantics.keyStackTrace] = stackTraceInBase64
        } catch let exception {
            Embrace.logger.error("Couldn't convert stack trace to json string: \(exception.localizedDescription)")
        }
    }

    @discardableResult
    func addStackTrace(_ stackTrace: [String]) -> Self {
        guard !stackTrace.isEmpty else {
            return self
        }
        let processedStackTrace = EMBStackTraceProccessor.processStackTrace(stackTrace)
        serializeProcessedStackTrace(processedStackTrace)
        return self
    }

    @discardableResult
    func addBacktrace(_ backtrace: EmbraceBacktrace) -> Self {
        guard let thread = backtrace.threads.first else {
            return self
        }
        let processedStackTrace = thread.frames(symbolicated: true).compactMap { $0.asProcessedFrame() }
        serializeProcessedStackTrace(processedStackTrace)
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
        return addApplicationProperties(sessionId: currentSession?.id)
    }

    @discardableResult
    func addApplicationProperties(sessionId: SessionIdentifier?) -> Self {
        guard let sessionId = sessionId,
            let storage = storage
        else {
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
        guard attributes[LogSemantics.keyState] == nil else {
            return self
        }

        return addApplicationState(currentSession?.state)
    }

    @discardableResult
    func addApplicationState(_ state: String?) -> Self {
        guard let state = state,
            attributes[LogSemantics.keyState] == nil
        else {
            return self
        }
        attributes[LogSemantics.keyState] = state
        return self
    }

    @discardableResult
    func addSessionIdentifier() -> Self {
        guard attributes[LogSemantics.keySessionId] == nil else {
            return self
        }

        return addSessionIdentifier(currentSession?.idRaw)
    }

    @discardableResult
    func addSessionIdentifier(_ sessionId: String?) -> Self {
        guard let sessionId = sessionId,
            attributes[LogSemantics.keySessionId] == nil
        else {
            return self
        }
        attributes[LogSemantics.keySessionId] = sessionId
        return self
    }

    @discardableResult
    func addCrashReportProperties() -> Self {
        return addCrashReportProperties(
            id: crashReport?.id.withoutHyphen,
            provider: crashReport?.provider,
            payload: crashReport?.payload
        )
    }

    @discardableResult
    func addCrashReportProperties(id: String?, provider: String?, payload: String?) -> Self {
        guard let id = id,
            let provider = provider,
            let payload = payload
        else {
            return self
        }

        attributes[LogSemantics.Crash.keyId] = id
        attributes[LogSemantics.Crash.keyProvider] = provider
        attributes[LogSemantics.Crash.keyPayload] = payload

        return self
    }

    @discardableResult
    func addHangReportProperties(id: String?, provider: String?, payload: String?, startTime: Date, endTime: Date)
        -> Self
    {
        guard let id = id,
            let provider = provider,
            let payload = payload
        else {
            return self
        }

        attributes[LogSemantics.Hang.keyId] = id
        attributes[LogSemantics.Hang.keyProvider] = provider
        attributes[LogSemantics.Hang.keyPayload] = payload
        attributes[LogSemantics.Hang.keyPayLoadTimestamp] = String(Date().nanosecondsSince1970Truncated)
        attributes[LogSemantics.Hang.keyDiagnosticTimestampStart] = String(startTime.nanosecondsSince1970Truncated)
        attributes[LogSemantics.Hang.keyDiagnosticTimestampEnd] = String(endTime.nanosecondsSince1970Truncated)

        return self
    }

    func build() -> [String: String] {
        attributes
    }
}
