//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Darwin
import UIKit

struct ApplicationProvider: BirdsEyeViewProvider {
    
    func provide(_ time: Date) -> BirdsEyeViewAttributes? {
        let app = UIApplication.shared
        var attributes: BirdsEyeViewAttributes = [:]
        DispatchQueue.main.sync {
            attributes["emb-app.state"] = app.applicationState.stringValue
        }
        attributes["emb-app.bgTimeRemaining"] = "\(app.backgroundTimeRemaining)"
        return attributes
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
            "emb-memory.app.used": "\(used)",
            "emb-memory.app.limit": "\(used + remaining)",
            "emb-memory.app.remaining": "\(remaining)",
            "emb-memory.app.compressed": "\(compressed)"
        ]
    }
    
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
