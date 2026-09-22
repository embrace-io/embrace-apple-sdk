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

    // Personas / user info are global SDK state, so we accumulate what was set during the app run and
    // verify the selected payload carries it. The public part id that used to key these per-session
    // is no longer exposed — and payloads keep personas/user-info set with carrying lifespans anyway,
    // so a single accumulated set is both simpler and accurate for what this test checks.
    private var recordedPersonas: Set<String> = []
    private var recordedUserInfo: UserInfo = .init()

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

    /// User-session id (`session.id`) of the most recently posted payload, surfaced from the network
    /// swizzle for display. The public API no longer exposes a session id, so this is our window into
    /// "the last session we actually sent".
    private(set) var lastPostedUserSessionId: String?

    var selectedPartId: String {
        didSet {
            testObject.partIdToTest = selectedPartId
        }
    }

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
    }

    func refresh() {
        updatedPostedParts()
        readUserInfoFromEmbrace()
        EmbraceIO.shared.getCurrentPersonas { [weak self] (personas: [String]) in
            guard let self = self else { return }
            personas.forEach { self.recordedPersonas.insert($0) }
        }
    }

    func clearAllUserInfo() {
        EmbraceIO.shared.removeAllProperties(lifespans: [])
        userInfoIdentifier = ""
        recordedUserInfo = .init()
    }

    func addedNewPersona(_ persona: String, lifespan: MetadataLifespan) {
        EmbraceIO.shared.addPersona(persona, lifespan: lifespan)
        recordedPersonas.insert(persona)
    }

    func removeAllPersonas() {
        EmbraceIO.shared.removeAllPersonas(lifespans: [])
        recordedPersonas.removeAll()
    }

    private func readUserInfoFromEmbrace() {
        let identifier = EmbraceIO.shared.userIdentifier
        self.userInfoIdentifier = identifier ?? ""
        recordedUserInfo = .init(identifier: identifier)
    }

    private func updatedUserInfo() {
        recordedUserInfo = .init(identifier: userInfoIdentifier)
    }

    private func updatedPostedParts() {
        // Don't clobber the list before the collector is wired (this view creates throwaway view
        // model instances via the `@State`-in-init pattern; those would otherwise reset it to []).
        guard let networkSpy = dataCollector?.networkSpy else { return }

        let postedPartIds = networkSpy.postedPartIds
        let exportedPartIds = Set(networkSpy.exportedSpansByPart.keys)
        postedParts = postedPartIds.filter { exportedPartIds.contains($0) }
        lastPostedUserSessionId = networkSpy.lastPostedUserSessionId
    }

    override func testButtonPressed() {
        guard let networkSpy = dataCollector?.networkSpy else { return }

        testObject.personas = Array(recordedPersonas)
        testObject.userInfo = recordedUserInfo

        super.testButtonPressed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let testResult = self.testObject.test(networkSwizzle: networkSpy)
            self.testFinished(with: testResult)
        }
    }
}
