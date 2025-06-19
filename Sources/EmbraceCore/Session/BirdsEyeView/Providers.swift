//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Darwin
import UIKit
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
#endif

// UIDevice.batteryLevel / .batteryState
// UIScreen.brightness
// UIApplication.protectedDataAvailable
// NSProcessInfo.isLowPowerModeEnabled
// NSProcessInfo.thermalState
// shared_cache_get_uuid
// thermal_notify_register
// UIScreen.maximumFramesPerSecond, CADisplayLink
// notify_register_dispatch
// memorystatus_control
// memorystatus_get_level

struct ResourceUsageProvider: BirdsEyeViewProvider {
    
    func provide(_ time: Date) -> BirdsEyeViewAttributes? {

        var info = rusage_info_current()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_CURRENT, $0)
            }
        }
        guard status == 0 else {
            return nil
        }
        return [
            "emb-rusage.billedEnergy": "\(info.ri_billed_energy)",
            "emb-rusage.mb.logicalWrites": "\(info.ri_logical_writes >> 20)",
            "emb-rusage.pageIns": "\(info.ri_pageins)",
            "emb-rusage.process.startTime": "\(info.ri_proc_start_abstime)",
            "emb-rusage.diskio.mb.read": "\(info.ri_diskio_bytesread >> 20)",
            "emb-rusage.diskio.mb.written": "\(info.ri_diskio_byteswritten >> 20)"
        ]
    }
    
    func stream() -> AsyncStream<[String]>? { nil }
}

@_silgen_name("proc_pid_rusage")
func proc_pid_rusage(
    _ pid: Int32,
    _ flavor: Int32,
    _ buffer: UnsafeMutableRawPointer
) -> Int32

class ApplicationProvider: BirdsEyeViewProvider {
    
    
    struct MutableData {
        var observers: [Any] = []
        var state: UIApplication.State = .background
    }
    private let state: EmbraceMutex<MutableData> = EmbraceMutex(MutableData())
    private var continuation: AsyncStream<[String]>.Continuation? = nil
    
    var applicationState: UIApplication.State {
        state.withLock { $0.state }
    }
    
    private func updateAndPushChangesIfNeeded() {
        dispatchPrecondition(condition: .onQueue(.main))
        let changed = state.withLock {
            let newState = UIApplication.shared.applicationState
            if newState != $0.state {
                $0.state = newState
                return true
            }
            return false
        }
        if changed {
            pushChangedValues()
        }
    }
    
    func register() -> Self {
        
        let names = [
            UIApplication.didFinishLaunchingNotification,
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willEnterForegroundNotification,
            UIApplication.willTerminateNotification
        ]
        
        var observers: [NSObjectProtocol] = []
        
        let center = NotificationCenter.default
        observers = names.map {
            center.addObserver(forName: $0,
                               object: UIApplication.shared,
                               queue: nil,
                               using: { [self] _ in
                updateAndPushChangesIfNeeded()
                RunLoop.main.perform(inModes: [.common]) {
                    updateAndPushChangesIfNeeded()
                }
            })
        }
        
        state.withLock {
            $0.observers.append(contentsOf: observers)
        }
        
        return self
    }
    
    deinit {
        let observers = state.withLock {
            let values = $0.observers
            $0.observers = []
            return values
        }
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }
    
    func pushChangedValues() {
        print("[ApplicationProvider] state changed \(applicationState)")
        continuation?.yield(["emb-app.state"])
    }
    
    func provide(_ time: Date) -> BirdsEyeViewAttributes? {
        let app = UIApplication.shared
        var attributes: BirdsEyeViewAttributes = [:]
        attributes["emb-app.state"] = state.withLock { $0.state }.stringValue
        attributes["emb-app.bgTimeRemaining"] = "\(app.backgroundTimeRemaining)"
        return attributes
    }
    
    func stream() -> AsyncStream<[String]>? {
        AsyncStream { continuation = $0 }
    }
}

struct MemoryProvider: BirdsEyeViewProvider {
    
    func provide(_ time: Date) -> BirdsEyeViewAttributes? {
        
        var info = task_vm_info_data_t()
        var infoCount = TASK_VM_INFO_COUNT
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, thread_flavor_t(TASK_VM_INFO), $0, &infoCount)
            }
        }
        guard  kerr == KERN_SUCCESS else {
            return nil
        }
        
        let used: Int64 = kerr == KERN_SUCCESS ? Int64(info.phys_footprint) : 0
        let compressed: Int64 = kerr == KERN_SUCCESS ? Int64(info.compressed) : 0
#if targetEnvironment(simulator)
        // In the simulator `limit_bytes_remaining` returns -1
        // which means we can't calculate limits.
        // Due to this, we just set it to 4GB.
        let limit: Int64 = 6_000_000_000
        let remaining: Int64 = max(limit - used, 0)
#else
        let remaining: Int64 = kerr == KERN_SUCCESS ? Int64(info.limit_bytes_remaining) : 0
#endif
        return [
            "emb-memory.app.mb.used": "\(used >> 20)",
            "emb-memory.app.mb.limit": "\((used + remaining) >> 20)",
            "emb-memory.app.mb.remaining": "\(remaining >> 20)",
            "emb-memory.app.mb.compressed": "\(compressed >> 20)"
        ]
    }
    
    func stream() -> AsyncStream<[String]>? { nil }
    
    private let TASK_BASIC_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_basic_info_data_t>.size / MemoryLayout<UInt32>.size)
    private let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<UInt32>.size)
}

struct TaskRoleProvider: BirdsEyeViewProvider {
    
    // policy
    func provide(_ time: Date) -> BirdsEyeViewAttributes? {
        
        var policyInfo = task_category_policy_data_t()
        var policyCount = mach_msg_type_number_t(MemoryLayout<task_category_policy_data_t>.size / MemoryLayout<natural_t>.size)
        var getDefault: boolean_t = 0
        
        let result = withUnsafeMutablePointer(to: &policyInfo) { policyPtr in
            return policyPtr.withMemoryRebound(to: integer_t.self, capacity: Int(policyCount)) { intPtr in
                return task_policy_get(
                    mach_task_self_,
                    task_policy_flavor_t(TASK_CATEGORY_POLICY),
                    intPtr,
                    &policyCount,
                    &getDefault
                )
            }
        }
        
        guard result == KERN_SUCCESS else {
            return nil
        }
        return [
            "emb-task.role": policyInfo.role.stringValue
        ]
    }
    
    func stream() -> AsyncStream<[String]>? { nil }
}

extension task_role_t {
    var stringValue: String {
        switch self {
        case TASK_RENICED: "TASK_RENICED"
        case TASK_UNSPECIFIED: "TASK_UNSPECIFIED"
        case TASK_FOREGROUND_APPLICATION: "TASK_FOREGROUND_APPLICATION"
        case TASK_BACKGROUND_APPLICATION: "TASK_BACKGROUND_APPLICATION"
        case TASK_CONTROL_APPLICATION: "TASK_CONTROL_APPLICATION"
        case TASK_GRAPHICS_SERVER: "TASK_GRAPHICS_SERVER"
        case TASK_THROTTLE_APPLICATION: "TASK_THROTTLE_APPLICATION"
        case TASK_NONUI_APPLICATION: "TASK_NONUI_APPLICATION"
        case TASK_DEFAULT_APPLICATION: "TASK_DEFAULT_APPLICATION"
        case TASK_DARWINBG_APPLICATION: "TASK_DARWINBG_APPLICATION"
        default: "TASK_UNKNOWN"
        }
    }
}

extension UIApplication.State {
    var stringValue: String {
        switch self {
        case .inactive: "inactive"
        case .active: "active"
        case .background: "background"
        }
    }
}
