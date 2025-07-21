//
//  UploadedSessionPayloadTestViewModel.swift
//  EmbraceIOTestApp
//
//

import EmbraceCore
import SwiftUI

@Observable
class UploadedSessionPayloadTestViewModel: UIComponentViewModelBase {
    private var testObject: UploadedSessionPayloadTest
    private var personasBySessionId: [String: Set<String>] = [:]
    private var userInfoBySessionId: [String: UserInfo] = [:]

    private(set) var exportedAndPostedSessions: [String] = [] {
        didSet {
            selectedSessionId = exportedAndPostedSessions.last ?? ""
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

    var userInfoUsername: String = "" {
        didSet {
            Embrace.client?.metadata.userName = userInfoUsername.isEmpty ? nil : userInfoUsername
            updatedUserInfo()
        }
    }

    var userInfoEmail: String = "" {
        didSet {
            Embrace.client?.metadata.userEmail = userInfoEmail.isEmpty ? nil : userInfoEmail
            updatedUserInfo()
        }
    }

    var userInfoIdentifier: String = "" {
        didSet {
            Embrace.client?.metadata.userIdentifier = userInfoIdentifier.isEmpty ? nil : userInfoIdentifier
            updatedUserInfo()
        }
    }

    init(dataModel: any TestScreenDataModel) {
        let testObject = UploadedSessionPayloadTest()
        self.testObject = testObject
        self.selectedSessionId = ""
        super.init(dataModel: dataModel, payloadTestObject: testObject)
        currentSessionId = Embrace.client?.currentSessionId()
        readUserInfoFromEmbrace()
        updatedExportedSessions()

        NotificationCenter.default.addObserver(
            forName: .init("NetworkingSwizzle.CapturedNewPayload"), object: nil, queue: nil
        ) { [weak self] _ in
            self?.updatedExportedSessions()
        }

        NotificationCenter.default.addObserver(forName: .embraceSessionDidStart, object: nil, queue: nil) {
            [weak self] _ in
            self?.currentSessionId = Embrace.client?.currentSessionId()
        }

        NotificationCenter.default.addObserver(forName: .embraceSessionWillEnd, object: nil, queue: nil) {
            [weak self] _ in
            self?.currentSessionId = nil
        }
    }

    func refresh() {
        updatedExportedSessions()
        readUserInfoFromEmbrace()
        Embrace.client?.metadata.getCurrentPersonas { [weak self] (personas: [String]) in
            guard let self = self else { return }
            personas.forEach { persona in
                self.addPersonaToCurrentSession(persona)
            }
        }
    }

    func clearAllUserInfo() {
        guard let currentSessionId = currentSessionId else { return }

        Embrace.client?.metadata.clearUserProperties()
        userInfoUsername = ""
        userInfoEmail = ""
        userInfoIdentifier = ""
        userInfoBySessionId[currentSessionId] = nil
    }

    func addedNewPersona(_ persona: String, lifespan: MetadataLifespan) {
        try? Embrace.client?.metadata.add(persona: persona, lifespan: lifespan)
        addPersonaToCurrentSession(persona)
    }

    private func addPersonaToCurrentSession(_ persona: String) {
        guard let currentSessionId = currentSessionId else { return }
        personasBySessionId[currentSessionId, default: []].insert(persona)
    }

    func removeAllPersonas() {
        Embrace.client?.metadata.removeAllPersonas()
        guard let currentSessionId = currentSessionId else { return }
        personasBySessionId[currentSessionId] = []
    }

    private func readUserInfoFromEmbrace() {
        guard let currentSessionId = currentSessionId else { return }
        let username = Embrace.client?.metadata.userName
        let email = Embrace.client?.metadata.userEmail
        let identifier = Embrace.client?.metadata.userIdentifier

        self.userInfoUsername = username ?? ""
        self.userInfoEmail = email ?? ""
        self.userInfoIdentifier = identifier ?? ""

        userInfoBySessionId[currentSessionId] = .init(username: username, email: email, identifier: identifier)
    }

    private func updatedUserInfo() {
        guard let currentSessionId = currentSessionId else { return }

        userInfoBySessionId[currentSessionId] = .init(
            username: userInfoUsername, email: userInfoEmail, identifier: userInfoIdentifier)
    }

    private func updatedExportedSessions() {
        let postedSessionIds = dataCollector?.networkSpy?.postedJsonsSessionIds ?? []
        let exportedSessionIds = dataCollector?.networkSpy?.exportedSpansBySession.keys.map { String($0) } ?? []
        exportedAndPostedSessions = postedSessionIds.filter { exportedSessionIds.contains($0) }
    }

    override func testButtonPressed() {
        guard let networkSpy = dataCollector?.networkSpy else { return }
        testObject.personas = Array(personasBySessionId[selectedSessionId, default: []])
        testObject.userInfo = userInfoBySessionId[selectedSessionId] ?? .init()
        super.testButtonPressed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let testResult = self.testObject.test(networkSwizzle: networkSpy)
            self.testFinished(with: testResult)
        }
    }
}
