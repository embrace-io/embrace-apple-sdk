//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
    import EmbraceObjCUtilsInternal
#endif

@objc(EMBStartupInstrumentation)
public class StartupInstrumentation: NSObject {

    var provider: StartupDataProvider
    var otel: EmbraceOpenTelemetry?

    struct MutableState {
        var rootSpan: Span?
        var firstFrameSpan: Span?
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
            $0.firstFrameSpan?.end(time: endTime)
            $0.rootSpan?.end(time: endTime)
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
        let rootBuilder = otel.buildSpan(
            name: SpanSemantics.Startup.parentName + "-" + provider.startupType.rawValue,
            type: .startup,
            attributes: attributes,
            autoTerminationCode: nil
        )
        rootBuilder.setStartTime(time: prewarmed ? startTime : processStartTime)
        let parent = rootBuilder.startSpan()

        // pre init (only on non-prewarmed startups)
        if !prewarmed {
            otel.recordCompletedSpan(
                name: SpanSemantics.Startup.preMainInitName,
                type: .startup,
                parent: parent,
                startTime: processStartTime,
                endTime: startTime,
                attributes: attributes,
                events: [],
                errorCode: nil
            )
        }

        // first frame rendered
        let firstFrameBuilder = otel.buildSpan(
            name: SpanSemantics.Startup.firstFrameRenderedName,
            type: .startup,
            attributes: attributes,
            autoTerminationCode: nil
        )
        firstFrameBuilder.setStartTime(time: startTime)
        firstFrameBuilder.setParent(parent)
        let firstFrameSpan = firstFrameBuilder.startSpan()

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
            otel.recordCompletedSpan(
                name: SpanSemantics.Startup.appInitName,
                type: .startup,
                parent: $0.rootSpan,
                startTime: provider.constructorClosestToMainTime,
                endTime: appDidFinishLaunchingTime,
                attributes: attributes,
                events: [],
                errorCode: nil
            )

            // sdk setup
            if let sdkSetupStartTime = provider.sdkSetupStartTime,
                let sdkSetupEndTime = provider.sdkSetupEndTime {
                otel.recordCompletedSpan(
                    name: SpanSemantics.Startup.sdkSetup,
                    type: .startup,
                    parent: $0.rootSpan,
                    startTime: sdkSetupStartTime,
                    endTime: sdkSetupEndTime,
                    attributes: attributes,
                    events: [],
                    errorCode: nil
                )
            }

            // sdk startup
            if let sdkStartStarTime = provider.sdkStartStartTime,
                let sdkStartEndTime = provider.sdkStartEndTime {
                otel.recordCompletedSpan(
                    name: SpanSemantics.Startup.sdkStart,
                    type: .startup,
                    parent: $0.rootSpan,
                    startTime: sdkStartStarTime,
                    endTime: sdkStartEndTime,
                    attributes: attributes,
                    events: [],
                    errorCode: nil
                )
            }
        }
    }
}
