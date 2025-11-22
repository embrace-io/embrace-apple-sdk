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

    struct ServiceMutableData {
        var enabled: Bool = true
        var observer: Any? = nil
    }
    private var serviceData = EmbraceMutex(ServiceMutableData())
    var enabled: Bool {
        get { serviceData.withLock { $0.enabled } }
        set { serviceData.withLock { $0.enabled = newValue } }
    }

    var observer: Any? {
        get { serviceData.withLock { $0.observer } }
        set { serviceData.withLock { $0.observer = newValue } }
    }

    public override func onInstall() {
        guard enabled else { return }
        observer = AppMemoryTracker.shared.addObserver { [weak self] memory, changes in
            self?.memoryChanged(memory: memory, with: changes)
        }
    }

    public override func onConfigUpdated(_ config: any EmbraceConfigurable) {
        enabled = config.memoryCaptureEnabled
    }

    fileprivate func memoryChanged(memory: AppMemory, with changes: AppMemoryTrackerChangeType) {
        guard isActive else {
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
