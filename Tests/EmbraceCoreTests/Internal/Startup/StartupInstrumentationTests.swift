//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import XCTest
@testable import EmbraceCore
import Foundation
import TestSupport

class StartupInstrumentationTests: XCTestCase {
    
    func test_noProcessStartTime() {
        // given no process start time
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.processStartTime = nil

        // when creating startup spans
        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        // then no spans are created
        XCTAssertEqual(otel.spanProcessor.startedSpans.count, 0)
        XCTAssertEqual(otel.spanProcessor.endedSpans.count, 0)
    }

    func test_cold() {
        // given a cold startup
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.startupType = .cold

        // when creating startup spans
        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        // then the parent span has the right name
        let parent = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertNotNil(parent)

        // and the time to first frame rendered span is included
        let firstFrame = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertNotNil(firstFrame)
        XCTAssertEqual(firstFrame?.parentSpanId, parent?.spanId)
    }

    func test_warm() {
        // given a warm startup
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.startupType = .warm

        // when creating startup spans
        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        // then the parent span has the right name
        let parent = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-warm" })
        XCTAssertNotNil(parent)

        // and the time to first frame rendered span is included
        let firstFrame = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertNotNil(firstFrame)
        XCTAssertEqual(firstFrame?.parentSpanId, parent?.spanId)
    }

    func test_prewarmed() {
        // given a prewarmed startup
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.isPrewarm = true

        // when creating startup spans
        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        // then the parent span has the right attribute
        let parent = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.attributes["isPrewarmed"]!.description, "true")

        // then the pre main init span is not included
        let preInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertNil(preInit)
    }

    func test_notPrewarmed() {
        // given a prewarmed startup
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.isPrewarm = false

        // when creating startup spans
        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        // then the parent span has the right attribute
        let parent = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.attributes["isPrewarmed"]!.description, "false")

        // then the pre main init span is included
        let preInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertNotNil(preInit)
    }

    func test_withoutAppDidFinishLaunching() {
        // given a no app did finish launching date
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.appDidFinishLaunchingEndTime = nil

        // when creating startup spans
        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        // then the app init and sdk spans are not created
        let appInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-app-init" })
        XCTAssertNil(appInit)

        let sdkSetup = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-setup" })
        XCTAssertNil(sdkSetup)

        let sdkStart = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-start" })
        XCTAssertNil(sdkStart)
    }

    func test_withAppDidFinishLaunching() {
        // given an app did finish launching date
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()

        // when creating startup spans
        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        // then the app init and sdk spans are created
        let appInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-app-init" })
        XCTAssertNotNil(appInit)

        let sdkSetup = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-setup" })
        XCTAssertNotNil(sdkSetup)

        let sdkStart = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-start" })
        XCTAssertNotNil(sdkStart)
    }

    func test_dates_prewarmed() {
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.isPrewarm = true

        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        let parent = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.startTime, provider.constructorClosestToMainTime)
        XCTAssertEqual(parent!.endTime, provider.firstFrameTime)

        let preInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertNil(preInit)

        let firstFrame = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertEqual(firstFrame!.startTime, provider.constructorClosestToMainTime)
        XCTAssertEqual(firstFrame!.endTime, provider.firstFrameTime)

        let appInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-app-init" })
        XCTAssertEqual(appInit!.startTime, provider.constructorClosestToMainTime)
        XCTAssertEqual(appInit!.endTime, provider.appDidFinishLaunchingEndTime)

        let sdkSetup = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-setup" })
        XCTAssertEqual(sdkSetup!.startTime, provider.sdkSetupStartTime)
        XCTAssertEqual(sdkSetup!.endTime, provider.sdkSetupEndTime)

        let sdkStart = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-start" })
        XCTAssertEqual(sdkStart!.startTime, provider.sdkStartStartTime)
        XCTAssertEqual(sdkStart!.endTime, provider.sdkStartEndTime)
    }

    func test_dates_nonPrewarmed() {
        let otel = MockEmbraceOpenTelemetry()
        let provider = MockStartupDataProvider()
        provider.isPrewarm = false

        StartupInstrumentation.buildSpans(startupDataProvider: provider, otel: otel)

        let parent = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-cold" })
        XCTAssertEqual(parent!.startTime, provider.processStartTime)
        XCTAssertEqual(parent!.endTime, provider.firstFrameTime)

        let preInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-pre-main-init" })
        XCTAssertEqual(preInit!.startTime, provider.processStartTime)
        XCTAssertEqual(preInit!.endTime, provider.constructorClosestToMainTime)

        let firstFrame = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-first-frame-rendered" })
        XCTAssertEqual(firstFrame!.startTime, provider.constructorClosestToMainTime)
        XCTAssertEqual(firstFrame!.endTime, provider.firstFrameTime)

        let appInit = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-app-startup-app-init" })
        XCTAssertEqual(appInit!.startTime, provider.constructorClosestToMainTime)
        XCTAssertEqual(appInit!.endTime, provider.appDidFinishLaunchingEndTime)

        let sdkSetup = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-setup" })
        XCTAssertEqual(sdkSetup!.startTime, provider.sdkSetupStartTime)
        XCTAssertEqual(sdkSetup!.endTime, provider.sdkSetupEndTime)

        let sdkStart = otel.spanProcessor.endedSpans.first(where: { $0.name == "emb-sdk-start" })
        XCTAssertEqual(sdkStart!.startTime, provider.sdkStartStartTime)
        XCTAssertEqual(sdkStart!.endTime, provider.sdkStartEndTime)
    }
}
