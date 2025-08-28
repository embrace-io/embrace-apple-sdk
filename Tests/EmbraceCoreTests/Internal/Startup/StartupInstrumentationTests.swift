//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
import Foundation
import TestSupport
@testable import EmbraceCore

class StartupInstrumentationTests: XCTestCase {

    var otel: MockOTelSignalsHandler!
    var provider: MockStartupDataProvider!
    var instrumentation: StartupInstrumentation!

    override func setUpWithError() throws {
        otel = MockOTelSignalsHandler()
        provider = MockStartupDataProvider()
        instrumentation = StartupInstrumentation(provider: provider)
        instrumentation.otel = otel
    }

    func test_noProcessStartTime() {
        // given no process start time
        provider.processStartTime = nil

        // when creating startup spans
        instrumentation.buildMainSpans()

        // then no spans are created
        XCTAssertEqual(otel.startedSpans.count, 0)
        XCTAssertEqual(otel.endedSpans.count, 0)
    }

    func test_cold() {
        // given a cold startup
        provider.startupType = .cold

        // when creating startup spans
        instrumentation.buildMainSpans()

        // then the parent span has the right name
        let parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertNotNil(parent)

        // and the time to first frame rendered span is included
        let firstFrame = otel.startedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertNotNil(firstFrame)
        XCTAssertEqual(firstFrame!.parentSpanId, parent!.context.spanId)
    }

    func test_warm() {
        // given a warm startup
        provider.startupType = .warm

        // when creating startup spans
        instrumentation.buildMainSpans()

        // then the parent span has the right name
        let parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-warm" })
        XCTAssertNotNil(parent)

        // and the time to first frame rendered span is included
        let firstFrame = otel.startedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertNotNil(firstFrame)
        XCTAssertEqual(firstFrame!.parentSpanId, parent!.context.spanId)
    }

    func test_prewarmed() {
        // given a prewarmed startup
        provider.isPrewarm = true

        // when creating startup spans
        instrumentation.buildMainSpans()

        // then the parent span has the right attribute
        let parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.attributes["isPrewarmed"]!.description, "true")

        // then the pre main init span is not included
        let preInit = otel.startedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertNil(preInit)
    }

    func test_notPrewarmed() {
        // given a non-prewarmed startup
        provider.isPrewarm = false

        // when creating startup spans
        instrumentation.buildMainSpans()

        // then the parent span has the right attribute
        let parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.attributes["isPrewarmed"]!.description, "false")

        // then the pre main init span is included
        let preInit = otel.startedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertNotNil(preInit)
    }

    func test_withoutAppDidFinishLaunching() {
        // given a no app did finish launching date
        provider.appDidFinishLaunchingEndTime = nil

        // when creating startup spans
        instrumentation.buildSecondarySpans(nil)

        // then the app init and sdk spans are not created
        let appInit = otel.endedSpans.first(where: { $0.name == "emb-app-startup-app-init" })
        XCTAssertNil(appInit)

        let sdkSetup = otel.endedSpans.first(where: { $0.name == "emb-sdk-setup" })
        XCTAssertNil(sdkSetup)

        let sdkStart = otel.endedSpans.first(where: { $0.name == "emb-sdk-start" })
        XCTAssertNil(sdkStart)
    }

    func test_withAppDidFinishLaunching() {
        // given an app did finish launching date
        // when creating startup spans
        instrumentation.buildSecondarySpans(provider.appDidFinishLaunchingEndTime)

        // then the app init and sdk spans are created
        let appInit = otel.endedSpans.first(where: { $0.name == "emb-app-startup-app-init" })
        XCTAssertNotNil(appInit)

        let sdkSetup = otel.endedSpans.first(where: { $0.name == "emb-sdk-setup" })
        XCTAssertNotNil(sdkSetup)

        let sdkStart = otel.endedSpans.first(where: { $0.name == "emb-sdk-start" })
        XCTAssertNotNil(sdkStart)
    }

    func test_dates_prewarmed() {
        provider.isPrewarm = true
        instrumentation.buildMainSpans()

        var parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.startTime, provider.constructorClosestToMainTime)

        let preInit = otel.endedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertNil(preInit)

        var firstFrame = otel.startedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertEqual(firstFrame!.startTime, provider.constructorClosestToMainTime)

        provider.firstFrameTime = Date(timeIntervalSince1970: 15)
        parent = otel.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.endTime, provider.firstFrameTime)

        firstFrame = otel.endedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertEqual(firstFrame!.endTime, provider.firstFrameTime)
    }

    func test_dates_nonPrewarmed() {
        provider.isPrewarm = false
        instrumentation.buildMainSpans()

        var parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.startTime, provider.processStartTime)

        let preInit = otel.endedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertEqual(preInit!.startTime, provider.processStartTime)
        XCTAssertEqual(preInit!.endTime, provider.constructorClosestToMainTime)

        var firstFrame = otel.startedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertEqual(firstFrame!.startTime, provider.constructorClosestToMainTime)

        provider.firstFrameTime = Date(timeIntervalSince1970: 15)
        parent = otel.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.endTime, provider.firstFrameTime)

        firstFrame = otel.endedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertEqual(firstFrame!.endTime, provider.firstFrameTime)
    }

    func test_dates_secondary() {
        instrumentation.buildMainSpans()
        provider.appDidFinishLaunchingEndTime = Date(timeIntervalSince1970: 14)

        let appInit = otel.endedSpans.first(where: { $0.name == "emb-app-startup-app-init" })
        XCTAssertEqual(appInit!.startTime, provider.constructorClosestToMainTime)
        XCTAssertEqual(appInit!.endTime, provider.appDidFinishLaunchingEndTime)

        let sdkSetup = otel.endedSpans.first(where: { $0.name == "emb-sdk-setup" })
        XCTAssertEqual(sdkSetup!.startTime, provider.sdkSetupStartTime)
        XCTAssertEqual(sdkSetup!.endTime, provider.sdkSetupEndTime)

        let sdkStart = otel.endedSpans.first(where: { $0.name == "emb-sdk-start" })
        XCTAssertEqual(sdkStart!.startTime, provider.sdkStartStartTime)
        XCTAssertEqual(sdkStart!.endTime, provider.sdkStartEndTime)
    }

    func test_buildChildSpan() {
        instrumentation.buildMainSpans()

        let span = instrumentation.createChildSpan(name: "test")
        XCTAssertNotNil(span)

        let parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(span!.parentSpanId, parent!.context.spanId)
    }

    func test_recordCompletedChildSpan() {
        instrumentation.buildMainSpans()

        let startTime = Date(timeIntervalSince1970: 10)
        let endTime = Date(timeIntervalSince1970: 11)

        let span = instrumentation.createChildSpan(name: "test", startTime: startTime, endTime: endTime)
        XCTAssertNotNil(span)
        XCTAssertEqual(span!.startTime, startTime)
        XCTAssertEqual(span!.endTime, endTime)

        let parent = otel.startedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(span!.parentSpanId, parent!.context.spanId)
    }

    func test_addAttributesToTrace() {
        provider.firstFrameTime = nil
        instrumentation.buildMainSpans()

        let result = try! instrumentation.addAttributesToTrace(["key1": "value1", "key2": "value2"])
        XCTAssertTrue(result)

        provider.firstFrameTime = Date(timeIntervalSince1970: 15)

        let parent = otel.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.attributes["key1"], "value1")
        XCTAssertEqual(parent!.attributes["key2"], "value2")
    }
}
