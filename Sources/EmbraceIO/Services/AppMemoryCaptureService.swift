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
    import EmbraceConfiguration
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
    private var enabled: EmbraceMutex<Bool> = EmbraceMutex(true)

    private override init() {
        // In KSCrash 2.3, the shared AppMemoryTracker is not accessible to the outside,
        // so for now i'm simply swizzling it. In 3.0, I've fixed it so it's accessible
        // and we'll just use that.
        AppMemoryTracker.embraceSwizzle()
    }

    public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
        enabled.safeValue = config.memoryCaptureEnabled
    }

    fileprivate func memoryChanged(memory: AppMemory, with changes: AppMemoryTrackerChangeType) {
        guard state == .active, enabled.safeValue else {
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

            let event = RecordingSpanEvent(
                name: eventName,
                timestamp: Date(),
                attributes: [
                    SpanEventSemantics.keyEmbraceType: .string(eventType),
                    SpanEventSemantics.Memory.level: .string(memory.level.asString()),
                    SpanEventSemantics.Memory.pressure: .string(memory.pressure.asString()),
                    SpanEventSemantics.Memory.footprint: .int(Int(memory.footprint)),
                    SpanEventSemantics.Memory.limit: .int(Int(memory.limit)),
                    SpanEventSemantics.Memory.remaining: .int(Int(memory.remaining))
                ]
            )
            add(event: event)
        }

        // update the footprint at the process level
        try? metadata?.setProcessProperty(key: SpanEventSemantics.Memory.level, value: memory.level.asString())
        try? metadata?.setProcessProperty(key: SpanEventSemantics.Memory.pressure, value: memory.pressure.asString())
        try? metadata?.setProcessProperty(key: SpanEventSemantics.Memory.footprint, value: "\(memory.footprint)")
        try? metadata?.setProcessProperty(key: SpanEventSemantics.Memory.limit, value: "\(memory.limit)")
        try? metadata?.setProcessProperty(key: SpanEventSemantics.Memory.remaining, value: "\(memory.remaining)")
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
