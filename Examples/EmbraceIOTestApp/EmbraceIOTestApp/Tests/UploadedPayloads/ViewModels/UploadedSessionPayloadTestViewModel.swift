//
//  UploadedSessionPayloadTestViewModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceCore

class UploadedSessionPayloadTestViewModel: UIComponentViewModelBase {
    private var testObject: UploadedSessionPayloadTest = .init()

    @Published private(set) var exportedAndPostedSessions: [String] = [] {
        didSet {
            selectedSessionId = exportedAndPostedSessions.last
        }
    }

    @Published private(set) var currentSessionId: String? {
        didSet {
            guard oldValue != nil else { return }
            self.lastSessionId = oldValue
        }
    }

    @Published var selectedSessionId: String? {
        didSet {
            guard let selectedSessionId = selectedSessionId else { return }
            testObject.sessionIdToTest = selectedSessionId
        }
    }

    @Published private(set) var lastSessionId: String?

    var testButtonDisabled: Bool {
        exportedAndPostedSessions.isEmpty
    }

    init(dataModel: any TestScreenDataModel) {
        super.init(dataModel: dataModel, payloadTestObject: self.testObject)
        currentSessionId = Embrace.client?.currentSessionId()
        NotificationCenter.default.addObserver(forName: .init("NetworkingSwizzle.CapturedNewPayload"), object: nil, queue: nil) { [weak self] _ in
            self?.updatedExportedSessions()
        }

        NotificationCenter.default.addObserver(forName: .embraceSessionDidStart, object: nil, queue: nil) { [weak self] _ in
            self?.currentSessionId = Embrace.client?.currentSessionId()
        }

        NotificationCenter.default.addObserver(forName: .embraceSessionWillEnd, object: nil, queue: nil) { [weak self] _ in
            self?.currentSessionId = nil
        }
    }

    private func updatedExportedSessions() {
        let postedSessionIds = dataCollector?.networkSpy?.postedJsonsSessionIds ?? []
        let exportedSessionIds = dataCollector?.networkSpy?.exportedSpansBySession.keys.map { String($0) } ?? []
        exportedAndPostedSessions = postedSessionIds.filter { exportedSessionIds.contains($0) }
    }

    override func testButtonPressed() {
        guard let networkSpy = dataCollector?.networkSpy else { return }
        super.testButtonPressed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let testResult = self.testObject.test(networkSwizzle: networkSpy)
            self.testFinished(with: testResult)
        }
    }
}
