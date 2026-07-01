//
//  UploadedSessionPayloadTestViewModel.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

@Observable
class UploadedSessionPayloadTestViewModel: UIComponentViewModelBase {
    private var testObject: UploadedSessionPayloadTest
    private var personasBySessionId: [String: Set<String>] = [:]
    private var userInfoBySessionId: [String: UserInfo] = [:]

    private(set) var exportedAndPostedSessions: [String] = [] {
        didSet {
            // Only default the selection when the current one is missing or no longer in the list.
            // Otherwise a newly-captured payload would silently override the session the user picked.
            if selectedSessionId.isEmpty || !exportedAndPostedSessions.contains(selectedSessionId) {
                selectedSessionId = exportedAndPostedSessions.last ?? ""
            }
        }
    }

    private(set) var currentSessionId: String? {
        didSet {
            guard oldValue != nil else { return }
            self.lastSessionId = oldValue
        }
    }

    var selectedSessionId: String {
        didSet {
            testObject.sessionIdToTest = selectedSessionId
        }
    }

    private(set) var lastSessionId: String?

    var testButtonDisabled: Bool {
        exportedAndPostedSessions.isEmpty
    }

    var userInfoIdentifier: String = "" {
        didSet {
            EmbraceIO.shared.userIdentifier = userInfoIdentifier.isEmpty ? nil : userInfoIdentifier
            updatedUserInfo()
        }
    }

    init(dataModel: any TestScreenDataModel) {
        let testObject = UploadedSessionPayloadTest()
        self.testObject = testObject
        self.selectedSessionId = ""
        super.init(dataModel: dataModel, payloadTestObject: testObject)
        currentSessionId = EmbraceIO.shared.currentSessionId
        readUserInfoFromEmbrace()
        updatedExportedSessions()

        NotificationCenter.default.addObserver(
            forName: .init("NetworkingSwizzle.CapturedNewPayload"), object: nil, queue: nil
        ) { [weak self] _ in
            self?.updatedExportedSessions()
        }

        NotificationCenter.default.addObserver(forName: .embraceSessionPartDidStart, object: nil, queue: nil) {
            [weak self] _ in
            self?.currentSessionId = EmbraceIO.shared.currentSessionId
        }

        NotificationCenter.default.addObserver(forName: .embraceUserSessionDidEnd, object: nil, queue: nil) {
            [weak self] _ in
            self?.currentSessionId = nil
        }
    }

    func refresh() {
        updatedExportedSessions()
        readUserInfoFromEmbrace()
        EmbraceIO.shared.getCurrentPersonas { [weak self] (personas: [String]) in
            guard let self = self else { return }
            personas.forEach { persona in
                self.addPersonaToCurrentSession(persona)
            }
        }
    }

    func clearAllUserInfo() {
        guard let currentSessionId = currentSessionId else { return }

        EmbraceIO.shared.removeAllProperties(lifespans: [])
        userInfoIdentifier = ""
        userInfoBySessionId[currentSessionId] = nil
    }

    func addedNewPersona(_ persona: String, lifespan: MetadataLifespan) {
        EmbraceIO.shared.addPersona(persona, lifespan: lifespan)
        addPersonaToCurrentSession(persona)
    }

    private func addPersonaToCurrentSession(_ persona: String) {
        guard let currentSessionId = currentSessionId else { return }
        personasBySessionId[currentSessionId, default: []].insert(persona)
    }

    func removeAllPersonas() {
        EmbraceIO.shared.removeAllPersonas(lifespans: [])
        guard let currentSessionId = currentSessionId else { return }
        personasBySessionId[currentSessionId] = []
    }

    private func readUserInfoFromEmbrace() {
        guard let currentSessionId = currentSessionId else { return }
        let identifier = EmbraceIO.shared.userIdentifier

        self.userInfoIdentifier = identifier ?? ""

        userInfoBySessionId[currentSessionId] = .init(identifier: identifier)
    }

    private func updatedUserInfo() {
        guard let currentSessionId = currentSessionId else { return }

        userInfoBySessionId[currentSessionId] = .init(identifier: userInfoIdentifier)
    }

    private func updatedExportedSessions() {
        let postedSessionIds = dataCollector?.networkSpy?.postedJsonsSessionIds ?? []
        let exportedSessionIds = dataCollector?.networkSpy?.exportedSpansBySession.keys.map { String($0) } ?? []
        exportedAndPostedSessions = postedSessionIds.filter { exportedSessionIds.contains($0) }
    }

    override func testButtonPressed() {
        guard let networkSpy = dataCollector?.networkSpy else { return }

        // Personas / user info are recorded keyed by the part id that was current when they were set
        // (`EmbraceIO.shared.currentSessionId`). The picker, however, is keyed by the payload's
        // `session.id` — the user-session id. Translate one to the other by reading the part id(s)
        // out of the posted payloads for the selected user session, then union the recorded values
        // across every part of that user session.
        let partIds = partIds(forUserSession: selectedSessionId, in: networkSpy)
        testObject.personas = Array(
            partIds.reduce(into: Set<String>()) { $0.formUnion(personasBySessionId[$1] ?? []) })
        testObject.userInfo = partIds.compactMap { userInfoBySessionId[$0] }.first ?? .init()

        super.testButtonPressed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let testResult = self.testObject.test(networkSwizzle: networkSpy)
            self.testFinished(with: testResult)
        }
    }

    /// Returns the `emb.session_part_id`s found in the posted payloads for the given user session
    /// (`session.id`). In v7 each part is uploaded as its own payload sharing the same `session.id`,
    /// so a user session can map to several part ids.
    private func partIds(forUserSession userSessionId: String, in networkSpy: NetworkingSwizzle) -> Set<String> {
        let posted = networkSpy.postedJsons[userSessionId] ?? []
        var ids = Set<String>()
        posted.forEach { json in
            let data = json["data"] as? JsonDictionary
            let spans = (data?["spans"] as? [JsonDictionary]) ?? []
            let snapshots = (data?["span_snapshots"] as? [JsonDictionary]) ?? []
            guard
                let sessionSpan = (spans + snapshots).first(where: { $0["name"] as? String == "emb-session" }),
                let attributes = sessionSpan["attributes"] as? [[String: String]],
                let partId = attributes.first(where: { $0["key"] == "emb.session_part_id" })?["value"]
            else {
                return
            }
            ids.insert(partId)
        }
        return ids
    }
}
