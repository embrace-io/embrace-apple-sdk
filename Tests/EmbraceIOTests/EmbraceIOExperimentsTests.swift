//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import XCTest

@testable import EmbraceCore
@testable import EmbraceIO

/// The eight public methods are pass-throughs to `ExperimentsHandler`, whose behaviour is covered by
/// `ExperimentsHandlerTests`. What matters here is that the surface is callable with its documented
/// defaults and that using it before the SDK is set up is a no-op rather than a crash.
final class EmbraceIOExperimentsTests: XCTestCase {

    override func setUpWithError() throws {
        Embrace.client = nil
    }

    override func tearDownWithError() throws {
        Embrace.client = nil
    }

    func test_trackExperiment_beforeSetup_isANoOp() {
        EmbraceIO.shared.trackExperiment(id: "exp")
        EmbraceIO.shared.trackExperiment(id: "exp", variant: "A")
        EmbraceIO.shared.trackExperiment(id: "exp", variant: "A", startedAt: Date())
    }

    func test_trackExperiments_beforeSetup_isANoOp() {
        EmbraceIO.shared.trackExperiments([])
        EmbraceIO.shared.trackExperiments([
            TrackedExperiment(id: "exp"),
            TrackedExperiment(id: "exp2", variant: "A", startedAt: Date())
        ])
    }

    func test_untrackExperiment_beforeSetup_isANoOp() {
        EmbraceIO.shared.untrackExperiment(id: "exp")
        EmbraceIO.shared.untrackExperiment(id: "exp", endedAt: Date())
    }

    func test_untrackExperiments_beforeSetup_isANoOp() {
        EmbraceIO.shared.untrackExperiments(ids: [])
        EmbraceIO.shared.untrackExperiments(ids: ["exp"], endedAt: Date())
    }

    func test_trackFeatureFlag_beforeSetup_isANoOp() {
        EmbraceIO.shared.trackFeatureFlag(id: "flag")
        EmbraceIO.shared.trackFeatureFlag(id: "flag", variant: "on")
        EmbraceIO.shared.trackFeatureFlag(id: "flag", variant: "on", startedAt: Date())
    }

    func test_trackFeatureFlags_beforeSetup_isANoOp() {
        EmbraceIO.shared.trackFeatureFlags([])
        EmbraceIO.shared.trackFeatureFlags([
            TrackedFeatureFlag(id: "flag"),
            TrackedFeatureFlag(id: "flag2", variant: "on", startedAt: Date())
        ])
    }

    func test_untrackFeatureFlag_beforeSetup_isANoOp() {
        EmbraceIO.shared.untrackFeatureFlag(id: "flag")
        EmbraceIO.shared.untrackFeatureFlag(id: "flag", endedAt: Date())
    }

    func test_untrackFeatureFlags_beforeSetup_isANoOp() {
        EmbraceIO.shared.untrackFeatureFlags(ids: [])
        EmbraceIO.shared.untrackFeatureFlags(ids: ["flag"], endedAt: Date())
    }
}
