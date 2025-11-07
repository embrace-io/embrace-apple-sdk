//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import EmbraceIO
import SwiftUI

struct ContentView: View {

    private func randomDoubleFullRange() -> Double {
        let sign: Double = Bool.random() ? 1 : -1
        let exponent = Double(Int.random(in: -1022...1023))
        let mantissa = Double.random(in: 1.0..<2.0)
        return sign * mantissa * pow(2.0, exponent)
    }

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

    var body: some View {
        VStack {
            Button("Test Logical Writes") {

                for _ in 0..<1000 {
                    let value = """
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()) #raw #record
                        """
                    Embrace.client?.add(event: .breadcrumb(value))
                    Embrace.client?.waitForAllWork()
                }

                // This will cause priority inversion but its for the greater good.
                Embrace.client?.waitForAllWork()
            }
            .accessibilityIdentifier("logical-writes-test-button")

            Button("Test Logical Writes With Debugging") {

                #if DEBUG
                    let formatter = ByteCountFormatStyle(style: .file, allowedUnits: .all)
                    let formatterFootprint = ByteCountFormatStyle(style: .memory, allowedUnits: .all)
                    let pre = logicalWrites()
                    var allValuesLW: [UInt64] = []
                    var allValuesPF: [UInt64] = []
                #endif

                for index in 0..<1000 {
                    let preWork = logicalWrites()
                    let value = """
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()),
                            \(randomDoubleFullRange()) #raw #record
                        """
                    Embrace.client?.add(event: .breadcrumb(value))
                    Embrace.client?.waitForAllWork()
                    #if DEBUG
                        let postWork = logicalWrites()
                        let countLW = postWork.logicalWrites &- preWork.logicalWrites
                        let countPF = postWork.footprint > preWork.footprint ? postWork.footprint &- preWork.footprint : 0
                        if countLW > 0 || countPF > 0 {
                            print("[LW] Logical Writes \(index): \(formatter.format(Int64(countLW))), footprint: \(formatterFootprint.format(Int64(countPF)))")
                        }
                        allValuesLW.append(countLW)
                        allValuesPF.append(countPF)
                    #endif
                }

                // This will cause priority inversion but its for the greater good.
                Embrace.client?.waitForAllWork()

                #if DEBUG
                    let post = logicalWrites()
                    let averageLW = Double(allValuesLW.reduce(0, +)) / Double(allValuesLW.count)
                    let averagePF = Double(allValuesPF.reduce(0, +)) / Double(allValuesPF.count)
                    let countPF = post.footprint > pre.footprint ? post.footprint &- pre.footprint : 0
                    print("[LW] Logical Writes: \(formatter.format(Int64(post.logicalWrites &- pre.logicalWrites))), avg: \(formatter.format(Int64(averageLW)))")
                    print("[LW] Footprint: \(formatterFootprint.format(Int64(countPF))), avg: \(formatterFootprint.format(Int64(averagePF)))")
                #endif
            }
            .accessibilityIdentifier("logical-writes-test-button-with-debug")
        }
        .padding()
    }
}

@_silgen_name("proc_pid_rusage")
func proc_pid_rusage(
    _ pid: Int32,
    _ flavor: Int32,
    _ buffer: UnsafeMutableRawPointer
) -> Int32

#Preview {
    ContentView()
}
