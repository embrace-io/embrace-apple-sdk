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

    // Personas / user info are recorded keyed by the part id that was current when they were set
    // (`EmbraceIO.shared.currentSessionId` is the part id). The picker also selects a part id, so
    // these look up directly at test time — no id translation needed.
    private var personasByPartId: [String: Set<String>] = [:]
    private var userInfoByPartId: [String: UserInfo] = [:]

    /// Part ids (`emb.session_part_id`) that have been uploaded — one entry per posted payload.
    private(set) var postedParts: [String] = [] {
        didSet {
            // Only default the selection when the current one is missing or no longer in the list,
            // so a newly-captured payload doesn't override the part the user picked.
            if selectedPartId.isEmpty || !postedParts.contains(selectedPartId) {
                selectedPartId = postedParts.last ?? ""
            }
        }
    }

    private(set) var currentSessionId: String? {
        didSet {
            if oldValue != nil {
                self.lastSessionId = oldValue
            }
        }
    }

    var selectedPartId: String {
        didSet {
            testObject.partIdToTest = selectedPartId
        }
    }

    private(set) var lastSessionId: String?

    var testButtonDisabled: Bool {
        postedParts.isEmpty
    }

    var userInfoIdentifier: String = "" {
        didSet {
            EmbraceIO.shared.userIdentifier = userInfoIdentifier.isEmpty ? nil : userInfoIdentifier
            updatedUserInfo()
        }
    }

    private var observerTokens: [NSObjectProtocol] = []

    init(dataModel: any TestScreenDataModel) {
        let testObject = UploadedSessionPayloadTest()
        self.testObject = testObject
        self.selectedPartId = ""
        super.init(dataModel: dataModel, payloadTestObject: testObject)
        currentSessionId = EmbraceIO.shared.currentSessionId
        readUserInfoFromEmbrace()
        // The posted-parts list is populated from `onAppear` (via `refresh()`), once
        // `dataCollector` is available — see `updatedPostedParts()`.
    }

    /// Registers the notification observers. Must be called from the view's `onAppear` (not `init`)
    /// so the observers bind to the instance SwiftUI actually renders: this view creates its view
    /// model inside the View initializer, where SwiftUI may spin up and discard several instances
    /// before keeping one in `@State`. Registering in `init` can leave the observers attached to a
    /// discarded instance, so the rendered view model never receives updates. Idempotent.
    ///
    /// Observers run on `.main`: `CapturedNewPayload` is posted from the URLSession swizzle on a
    /// background thread, and mutating `@Observable` state off the main thread doesn't reliably
    /// drive SwiftUI updates.
    func startObserving() {
        guard observerTokens.isEmpty else { return }

        observerTokens.append(
            NotificationCenter.default.addObserver(
                forName: .init("NetworkingSwizzle.CapturedNewPayload"), object: nil, queue: .main
            ) { [weak self] _ in
                self?.updatedPostedParts()
            })

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .embraceSessionPartDidStart, object: nil, queue: .main) {
                [weak self] _ in
                self?.currentSessionId = EmbraceIO.shared.currentSessionId
            })

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .embraceUserSessionDidEnd, object: nil, queue: .main) {
                [weak self] _ in
                self?.currentSessionId = nil
            })
    }

    func refresh() {
        updatedPostedParts()
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
        userInfoByPartId[currentSessionId] = nil
    }

    func addedNewPersona(_ persona: String, lifespan: MetadataLifespan) {
        EmbraceIO.shared.addPersona(persona, lifespan: lifespan)
        addPersonaToCurrentSession(persona)
    }

    private func addPersonaToCurrentSession(_ persona: String) {
        guard let currentSessionId = currentSessionId else { return }
        personasByPartId[currentSessionId, default: []].insert(persona)
    }

    func removeAllPersonas() {
        EmbraceIO.shared.removeAllPersonas(lifespans: [])
        guard let currentSessionId = currentSessionId else { return }
        personasByPartId[currentSessionId] = []
    }

    private func readUserInfoFromEmbrace() {
        guard let currentSessionId = currentSessionId else { return }
        let identifier = EmbraceIO.shared.userIdentifier

        self.userInfoIdentifier = identifier ?? ""

        userInfoByPartId[currentSessionId] = .init(identifier: identifier)
    }

    private func updatedUserInfo() {
        guard let currentSessionId = currentSessionId else { return }

        userInfoByPartId[currentSessionId] = .init(identifier: userInfoIdentifier)
    }

    private func updatedPostedParts() {
        // Don't clobber the list before the collector is wired (this view creates throwaway view
        // model instances via the `@State`-in-init pattern; those would otherwise reset it to []).
        guard let networkSpy = dataCollector?.networkSpy else { return }

        let postedPartIds = networkSpy.postedPartIds
        let exportedPartIds = Set(networkSpy.exportedSpansByPart.keys)
        postedParts = postedPartIds.filter { exportedPartIds.contains($0) }
    }

    override func testButtonPressed() {
        guard let networkSpy = dataCollector?.networkSpy else { return }

        testObject.personas = Array(personasByPartId[selectedPartId, default: []])
        testObject.userInfo = userInfoByPartId[selectedPartId] ?? .init()

        super.testButtonPressed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let testResult = self.testObject.test(networkSwizzle: networkSpy)
            self.testFinished(with: testResult)
        }
    }
}
