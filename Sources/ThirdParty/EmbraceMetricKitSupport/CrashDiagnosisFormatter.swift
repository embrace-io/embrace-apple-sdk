import Foundation
import MetricKit

// https://developer.apple.com/documentation/xcode/understanding-the-exception-types-in-a-crash-report
// https://developer.apple.com/documentation/xcode/examining-the-fields-in-a-crash-report#Exception-information
// https://developer.apple.com/documentation/xcode/addressing-watchdog-terminations
// https://developer.apple.com/documentation/xcode/investigating-memory-access-crashes
public final class CrashDiagnosisFormatter {

    func diagnosis(from d: CrashDiagnostic) -> String {
        
        var parts: [String] = []
        
        if let mach = d.metaData.machException {
            parts.append(mach.name)
        }
        
        if let signal = d.metaData.crashSignal {
            parts.append("(\(signal.stringValue))")
        }
        
        if let code = d.metaData.terminationReasonCode {
            parts.append(code)
        }
        
        return parts.joined(separator: " ")
    }
}
