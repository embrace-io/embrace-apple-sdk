//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceOTelInternal
import EmbraceSemantics
import EmbraceObjCUtilsInternal

class StartupInstrumentation {

    static func buildSpans(startupDataProvider: StartupDataProvider, otel: EmbraceOpenTelemetry) {
        guard let processStartTime = startupDataProvider.processStartTime else {
            return
        }

        // prewarm
        let prewarmed = startupDataProvider.isPrewarm
        let preWarmStr = prewarmed ? "true" : "false"
        let attributes = [SpanSemantics.Startup.keyPrewarmed: preWarmStr]

        // start and end times
        let startTime = startupDataProvider.constructorClosestToMainTime
        let endTime = startupDataProvider.firstFrameTime

        // build parent
        let builder = otel.buildSpan(
            name: SpanSemantics.Startup.parentName + "-" + startupDataProvider.startupType.rawValue,
            type: .startup,
            attributes: attributes,
            autoTerminationCode: nil
        )
        builder.setStartTime(time: prewarmed ? startTime : processStartTime)

        let parent = builder.startSpan()
        parent.end(time: endTime)

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
        otel.recordCompletedSpan(
            name: SpanSemantics.Startup.firstFrameRenderedName,
            type: .startup,
            parent: parent,
            startTime: startTime,
            endTime: endTime,
            attributes: attributes,
            events: [],
            errorCode: nil
        )

        if let appDidFinishLaunchingTime = startupDataProvider.appDidFinishLaunchingEndTime {

            // app init
            otel.recordCompletedSpan(
                name: SpanSemantics.Startup.appInitName,
                type: .startup,
                parent: parent,
                startTime: startTime,
                endTime: appDidFinishLaunchingTime,
                attributes: attributes,
                events: [],
                errorCode: nil
            )

            // sdk setup
            if let sdkSetupStartTime = startupDataProvider.sdkSetupStartTime,
               let sdkSetupEndTime = startupDataProvider.sdkSetupEndTime {
                otel.recordCompletedSpan(
                    name: SpanSemantics.Startup.sdkSetup,
                    type: .startup,
                    parent: parent,
                    startTime: sdkSetupStartTime,
                    endTime: sdkSetupEndTime,
                    attributes: attributes,
                    events: [],
                    errorCode: nil
                )
            }

            // sdk startup
            if let sdkStartStarTime = startupDataProvider.sdkStartStartTime,
               let sdkStartEndTime = startupDataProvider.sdkStartEndTime {
                otel.recordCompletedSpan(
                    name: SpanSemantics.Startup.sdkStart,
                    type: .startup,
                    parent: parent,
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
