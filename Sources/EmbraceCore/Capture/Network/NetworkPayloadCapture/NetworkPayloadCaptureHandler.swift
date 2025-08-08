//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceConfigInternal
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import EmbraceSemantics
    import EmbraceConfiguration
#endif

protocol NetworkPayloadCaptureHandler {
    func isEnabled() -> Bool
    func process(
        request: URLRequest?,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        startTime: Date?,
        endTime: Date?
    )
}

class DefaultNetworkPayloadCaptureHandler: NetworkPayloadCaptureHandler {

    struct MutableState {
        var active: Bool = false
        var rules: [URLSessionTaskCaptureRule] = []
        var rulesTriggeredMap: [String: Bool] = [:]
        var currentSessionId: SessionIdentifier?
    }
    internal var state: EmbraceMutex<MutableState>

    private var otel: EmbraceOpenTelemetry?

    init(otel: EmbraceOpenTelemetry?) {
        self.otel = otel
        self.state = EmbraceMutex(MutableState())

        Embrace.notificationCenter.addObserver(
            self,
            selector: #selector(onConfigUpdated),
            name: .embraceConfigUpdated, object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionStart),
            name: Notification.Name.embraceSessionDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSessionEnd),
            name: Notification.Name.embraceSessionWillEnd,
            object: nil
        )

        updateRules(Embrace.client?.config.networkPayloadCaptureRules)

        // check if a session is already started
        if let sessionId = Embrace.client?.currentSessionId() {
            state.withLock {
                $0.active = true
                $0.currentSessionId = SessionIdentifier(string: sessionId)
            }
        }
    }

    deinit {
        Embrace.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    func updateRules(_ rules: [NetworkPayloadCaptureRule]?) {
        guard let rules = rules else {
            return
        }

        let newRules = rules.map { URLSessionTaskCaptureRule(rule: $0) }
        state.withLock {
            $0.rules = newRules
        }
    }

    @objc private func onConfigUpdated(_ notification: Notification) {
        let config = notification.object as? EmbraceConfigurable
        updateRules(config?.networkPayloadCaptureRules)
    }

    @objc func onSessionStart(_ notification: Notification) {
        state.withLock {
            $0.active = true
            $0.rulesTriggeredMap.removeAll()
            $0.currentSessionId = (notification.object as? EmbraceSession)?.id
        }
    }

    @objc func onSessionEnd() {
        state.withLock {
            $0.active = false
            $0.currentSessionId = nil
        }
    }

    public func process(
        request: URLRequest?,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        startTime: Date?,
        endTime: Date?
    ) {
        var protectedDataCopy = state.safeValue

        guard protectedDataCopy.active else {
            return
        }

        for rule in protectedDataCopy.rules {
            // check if rule was already triggered
            guard protectedDataCopy.rulesTriggeredMap[rule.id] == nil else {
                continue
            }

            // check if rule applies for this task
            guard rule.shouldTriggerFor(request: request, response: response, error: error) else {
                continue
            }

            // generate payload
            guard
                let payload = EncryptedNetworkPayload(
                    request: request,
                    response: response,
                    data: data,
                    error: error,
                    startTime: startTime,
                    endTime: endTime,
                    matchedUrl: rule.urlRegex,
                    sessionId: protectedDataCopy.currentSessionId
                )
            else {
                Embrace.logger.debug("Couldn't generate payload for task \(rule.urlRegex)!")
                return
            }

            // encrypt payload
            guard let result = payload.encrypted(withKey: rule.publicKey) else {
                Embrace.logger.debug("Couldn't encrypt payload for task \(rule.urlRegex)!")
                return
            }

            // generate otel log
            otel?.log(
                "",
                severity: .info,
                type: .networkCapture,
                attributes: [
                    LogSemantics.NetworkCapture.keyUrl: payload.url,
                    LogSemantics.NetworkCapture.keyEncryptionMechanism: result.mechanism,
                    LogSemantics.NetworkCapture.keyEncryptedPayload: result.payload,
                    LogSemantics.NetworkCapture.keyPayloadAlgorithm: result.payloadAlgorithm,
                    LogSemantics.NetworkCapture.keyEncryptedKey: result.key,
                    LogSemantics.NetworkCapture.keyKeyAlgorithm: result.keyAlgorithm,
                    LogSemantics.NetworkCapture.keyAesIv: result.iv
                ],
                stackTraceBehavior: .default
            )

            // flag rule as triggered
            protectedDataCopy.rulesTriggeredMap[rule.id] = true
        }

        // udpate all mutations to protected data
        state.withLock {
            $0.rulesTriggeredMap = protectedDataCopy.rulesTriggeredMap
        }
    }

    func isEnabled() -> Bool {
        state.withLock {
            $0.active && $0.rules.isEmpty == false
        }
    }
}
