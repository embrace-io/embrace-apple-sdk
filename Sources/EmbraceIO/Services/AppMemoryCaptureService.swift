//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import ObjectiveC.runtime
import OpenTelemetryApi

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCaptureService
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceSemantics
#endif

#if canImport(KSCrashRecording)
    import KSCrashRecording
#elseif canImport(KSCrash)
    import KSCrash
#endif

public class AppMemoryCaptureService: CaptureService {

    // This is shared for now until we have access to the AppMemoryTracker
    // and can add an observer. See `init` for why.
    public static let shared = AppMemoryCaptureService()

    private override init() {
        // In KSCrash 2.3, the shared AppMemoryTracker is not accessible to the outside,
        // so for now i'm simply swizzling it. In 3.0, I've fixed it so it's accessible
        // and we'll just use that.
        AppMemoryTracker.embraceSwizzle()
    }

    fileprivate func memoryChanged(memory: AppMemory, with changes: AppMemoryTrackerChangeType) {
        guard state == .active else {
            return
        }

        let eventName: String?
        let eventType: String?

        if changes.contains(.level) {
            eventName = SpanEventSemantics.MemoryLevel.name
            eventType = SpanEventType.memoryLevel.rawValue
        } else if changes.contains(.pressure) {
            eventName = SpanEventSemantics.MemoryPressure.name
            eventType = SpanEventType.memoryPressure.rawValue
        } else {
            eventName = nil
            eventType = nil
        }

        // send pressure or level updates
        if let eventName, let eventType {

            let date = Date()

            let event = RecordingSpanEvent(
                name: eventName,
                timestamp: date,
                attributes: [
                    SpanEventSemantics.keyEmbraceType: .string(eventType),
                    "emb.memory_level": .string(memory.level.asString()),
                    "emb.memory_pressure": .string(memory.pressure.asString()),
                    "emb.memory_footprint": .int(Int(memory.footprint)),
                    "emb.memory_limit": .int(Int(memory.limit)),
                    "emb.memory_remaining": .int(Int(memory.remaining))
                ]
            )
            add(event: event)

            otel?.log(
                eventName,
                severity: .warn,
                type: .message,
                timestamp: date,
                attributes: [
                    "emb.memory_level": memory.level.asString(),
                    "emb.memory_pressure": memory.pressure.asString(),
                    "emb.memory_footprint": "\(memory.footprint)",
                    "emb.memory_limit": "\(memory.limit)",
                    "emb.memory_remaining": "\(memory.remaining)"
                ],
                stackTraceBehavior: .notIncluded
            )
        }

        // update the footprint at the process level
        try? metadata?.setProperty(key: "emb.memory_level", value: memory.level.asString(), lifespan: .process)
        try? metadata?.setProperty(key: "emb.memory_pressure", value: memory.pressure.asString(), lifespan: .process)
        try? metadata?.setProperty(key: "emb.memory_footprint", value: "\(memory.footprint)", lifespan: .process)
        try? metadata?.setProperty(key: "emb.memory_limit", value: "\(memory.limit)", lifespan: .process)
        try? metadata?.setProperty(key: "emb.memory_remaining", value: "\(memory.remaining)", lifespan: .process)
    }
}

extension AppMemoryState {
    func asString() -> String {
        String(cString: cString())
    }
}

extension AppMemoryTracker {

    // Replacement implementation (Swift side).
    // Keep the *Swift* signature matching the Obj-C selector `_handleMemoryChange:type:`
    // i.e. `_handleMemoryChange(_:type:)` once imported to Swift.
    @objc
    dynamic
        func embHandleMemoryChange(_ memory: AppMemory, type changes: AppMemoryTrackerChangeType)
    {

        // tell the capture service
        AppMemoryCaptureService.shared.memoryChanged(memory: memory, with: changes)

        // Call the original implementation (now swapped)
        embHandleMemoryChange(memory, type: changes)
    }

    fileprivate static func embraceSwizzle() {
        let cls: AnyClass = AppMemoryTracker.self

        // Original Obj-C selector is `_handleMemoryChange:type:`
        let originalSel = NSSelectorFromString("_handleMemoryChange:type:")
        let swizzledSel = #selector(AppMemoryTracker.embHandleMemoryChange(_:type:))

        guard
            let originalMethod = class_getInstanceMethod(cls, originalSel),
            let swizzledMethod = class_getInstanceMethod(cls, swizzledSel)
        else {
            return
        }

        // If the original method is inherited, class_addMethod will succeed
        // and we then replace the swizzled selector to point at the original IMP.
        let didAdd = class_addMethod(
            cls,
            originalSel,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAdd {
            class_replaceMethod(
                cls,
                swizzledSel,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}
