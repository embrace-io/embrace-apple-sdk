//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceSemantics
    import EmbraceObjCUtilsInternal
#endif

@objc(EMBStartupInstrumentation)
public class StartupInstrumentation: NSObject {

    var provider: StartupDataProvider
    var otel: OTelSignalsHandler?

    struct MutableState {
        var rootSpan: EmbraceSpan?
        var firstFrameSpan: EmbraceSpan?
    }
    internal var state: EmbraceMutex<MutableState>

    init(provider: StartupDataProvider = DefaultStartupDataProvider()) {
        self.provider = provider
        self.state = EmbraceMutex(MutableState())

        super.init()

        self.provider.onFirstFrameTimeSet = { [weak self] date in
            self?.endSpans(date)
        }

        self.provider.onAppDidFinishLaunchingEndTimeSet = { [weak self] date in
            self?.buildSecondarySpans(date)
        }
    }

    func endSpans(_ endTime: Date) {
        state.withLock {
            $0.firstFrameSpan?.end(endTime: endTime)
            $0.rootSpan?.end(endTime: endTime)
        }
    }

    func buildMainSpans() {
        guard let otel = otel,
            let processStartTime = provider.processStartTime
        else {
            return
        }

        // prewarm
        let prewarmed = provider.isPrewarm
        let preWarmStr = prewarmed ? "true" : "false"
        let attributes = [SpanSemantics.Startup.keyPrewarmed: preWarmStr]

        // start time
        let startTime = provider.constructorClosestToMainTime

        // build parent
        let parent = try? otel.createSpan(
            name: SpanSemantics.Startup.parentName + "-" + provider.startupType.rawValue,
            type: .startup,
            startTime: prewarmed ? startTime : processStartTime,
            attributes: attributes
        )

        // pre init (only on non-prewarmed startups)
        if !prewarmed {
            _ = try? otel.createSpan(
                name: SpanSemantics.Startup.preMainInitName,
                parentSpan: parent,
                type: .startup,
                startTime: processStartTime,
                endTime: startTime,
                attributes: attributes
            )
        }

        // first frame rendered
        let firstFrameSpan = try? otel.createSpan(
            name: SpanSemantics.Startup.firstFrameRenderedName,
            parentSpan: parent,
            type: .startup,
            startTime: startTime,
            attributes: attributes
        )

        // save state
        state.withLock {
            $0.rootSpan = parent
            $0.firstFrameSpan = firstFrameSpan
        }

        if let firstFrameTime = provider.firstFrameTime {
            endSpans(firstFrameTime)
        }
    }

    func buildSecondarySpans(_ appDidFinishLaunchingTime: Date?) {
        guard let otel = otel,
            let appDidFinishLaunchingTime = appDidFinishLaunchingTime
        else {
            return
        }

        state.withLock {
            let attributes = [
                SpanSemantics.Startup.keyPrewarmed: provider.isPrewarm ? "true" : "false"
            ]

            // app init
            _ = try? otel.createSpan(
                name: SpanSemantics.Startup.appInitName,
                parentSpan: $0.rootSpan,
                type: .startup,
                startTime: provider.constructorClosestToMainTime,
                endTime: appDidFinishLaunchingTime,
                attributes: attributes
            )

            // sdk setup
            if let sdkSetupStartTime = provider.sdkSetupStartTime,
                let sdkSetupEndTime = provider.sdkSetupEndTime
            {
                _ = try? otel.createSpan(
                    name: SpanSemantics.Startup.sdkSetup,
                    parentSpan: $0.rootSpan,
                    type: .startup,
                    startTime: sdkSetupStartTime,
                    endTime: sdkSetupEndTime,
                    attributes: attributes
                )
            }

            // sdk startup
            if let sdkStartStarTime = provider.sdkStartStartTime,
                let sdkStartEndTime = provider.sdkStartEndTime
            {
                _ = try? otel.createSpan(
                    name: SpanSemantics.Startup.sdkStart,
                    parentSpan: $0.rootSpan,
                    type: .startup,
                    startTime: sdkStartStarTime,
                    endTime: sdkStartEndTime,
                    attributes: attributes
                )
            }
        }
    }
}
