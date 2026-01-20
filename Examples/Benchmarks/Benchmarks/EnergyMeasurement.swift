//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import Foundation
import SwiftUI

/// A helper that measures energy usage and exposes it to UI tests via mach ports
class EnergyMeasurement {
    static let shared = EnergyMeasurement()

    func logicalWrites() -> (logicalWrites: UInt64, footprint: UInt64) {
        var info = rusage_info_current()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_CURRENT, $0)
            }
        }
        guard status == 0 else {
            return (0, 0)
        }
        return (info.ri_logical_writes, info.ri_phys_footprint)
    }
}

@_silgen_name("proc_pid_rusage")
func proc_pid_rusage(
    _ pid: Int32,
    _ flavor: Int32,
    _ buffer: UnsafeMutableRawPointer
) -> Int32
