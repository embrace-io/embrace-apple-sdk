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

class NetworkPayloadCaptureHandler {

    @ThreadSafe
    var active = false

    @ThreadSafe
    var rules: [URLSessionTaskCaptureRule] = []

    @ThreadSafe
    var rulesTriggeredMap: [String: Bool] = [:]

    @ThreadSafe
    var currentSessionId: SessionIdentifier?

    private var otel: EmbraceOpenTelemetry?

    init(otel: EmbraceOpenTelemetry?) {
        self.otel = otel

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

        updateRules(Embrace.client?.config?.networkPayloadCaptureRules)

        // check if a session is already started
        if let sessionId = Embrace.client?.currentSessionId() {
            active = true
            currentSessionId = SessionIdentifier(string: sessionId)
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

        self.rules = rules.map { URLSessionTaskCaptureRule(rule: $0) }
    }

    @objc private func onConfigUpdated(_ notification: Notification) {
        let config = notification.object as? EmbraceConfig
        updateRules(config?.networkPayloadCaptureRules)
    }

    @objc func onSessionStart(_ notification: Notification) {
        active = true
        rulesTriggeredMap.removeAll()

        currentSessionId = (notification.object as? EmbraceSession)?.id
    }

    @objc func onSessionEnd() {
        active = false
        currentSessionId = nil
    }

    public func process(
        request: URLRequest?,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        startTime: Date?,
        endTime: Date?
    ) {

        guard active else {
            return
        }

        for rule in rules {
            // check if rule was already triggered
            guard rulesTriggeredMap[rule.id] == nil else {
                continue
            }

            // check if rule applies for this task
            guard rule.shouldTriggerFor(request: request, response: response, error: error) else {
                continue
            }

            // generate payload
            guard let payload = EncryptedNetworkPayload(
                request: request,
                response: response,
                data: data,
                error: error,
                startTime: startTime,
                endTime: endTime,
                matchedUrl: rule.urlRegex,
                sessionId: currentSessionId
            ) else {
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
            rulesTriggeredMap[rule.id] = true
        }
    }
}
