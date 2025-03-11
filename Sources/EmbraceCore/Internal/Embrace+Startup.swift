//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceObjCUtilsInternal
import EmbraceSemantics

extension Embrace {
    func addStartupTraces() {
        guard let processStartTime = ProcessMetadata.startTime else {
            return
        }

        let preWarmStr = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1" ? "true" : "false"
        let attributes = [SpanSemantics.Startup.keyPrewarmed: preWarmStr]

        let startTime = EMBStartupTracker.shared().constructorClosestToMainTime as Date
        let endTime = EMBStartupTracker.shared().firstFrameTime as Date

        // build parent
        let builder = buildSpan(
            name: SpanSemantics.Startup.parentWarmName,
            attributes: attributes
        )
        builder.setStartTime(time: processStartTime)

        let parent = builder.startSpan()
        parent.end(time: endTime)

        // pre init
        recordCompletedSpan(
            name: SpanSemantics.Startup.preMainInitName,
            type: .startup,
            parent: parent,
            startTime: processStartTime,
            endTime: startTime,
            attributes: attributes,
            events: [],
            errorCode: nil
        )

        // first frame rendered
        recordCompletedSpan(
            name: SpanSemantics.Startup.firstFrameRenderedName,
            type: .startup,
            parent: parent,
            startTime: startTime,
            endTime: endTime,
            attributes: attributes,
            events: [],
            errorCode: nil
        )

        if let appDidFinishLaunchingTime = EMBStartupTracker.shared().appDidFinishLaunchingEndTime {

            // app init
            recordCompletedSpan(
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
            if let sdkSetupStartTime = EMBStartupTracker.shared().sdkSetupStartTime,
               let sdkSetupEndTime = EMBStartupTracker.shared().sdkSetupEndTime {
                recordCompletedSpan(
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
            if let sdkStartStarTime = EMBStartupTracker.shared().sdkStartStartTime,
               let sdkStartEndTime = EMBStartupTracker.shared().sdkStartEndTime {
                recordCompletedSpan(
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
