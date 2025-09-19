//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct TerminationReason {
    let type: String = "RBSTerminateContext"
    let domain: Int?
    let code: String?
    let explanation: String?
    let app: AppInfo
    let timeout: Double?
    let processVisibility: String?
    let processState: String?
    let watchdog: WatchdogInfo
    let thermal: ThermalInfo
    let reportType: String?
    let maxTerminationResistance: String?

    struct AppInfo {
        let bundleId: String?
        let uuid: String?
        let pid: Int?
    }

    struct WatchdogInfo {
        let event: String?
        let visibility: String?
        let cpuStatistics: CPUStatistics

        struct CPUStatistics {
            let totalCpuTime: Double?
            let userTime: Double?
            let systemTime: Double?
            let totalCpuPercent: Int?
            let appCpuTime: Double?
            let appCpuPercent: Int?
        }
    }

    struct ThermalInfo {
        let level: Int?
        let state: String?
    }
}

class TerminationReasonParser {

    enum ParseError: Error {
        case invalidFormat(String)
        case regexError(String)
    }

    /// Parse an RBS termination context log entry
    /// - Parameter logEntry: The raw log entry string
    /// - Returns: Parsed RBSTerminationContext object
    /// - Throws: ParseError if parsing fails
    static func parse(_ logEntry: String) throws -> TerminationReason {

        var domain: Int?
        var code: String?
        var explanation: String?
        var appInfo = TerminationReason.AppInfo(bundleId: nil, uuid: nil, pid: nil)
        var timeout: Double?
        var processVisibility: String?
        var processState: String?
        var watchdogEvent: String?
        var watchdogVisibility: String?
        var cpuStats = TerminationReason.WatchdogInfo.CPUStatistics(
            totalCpuTime: nil, userTime: nil, systemTime: nil,
            totalCpuPercent: nil, appCpuTime: nil, appCpuPercent: nil
        )
        var thermalLevel: Int?
        var thermalState: String?
        var reportType: String?
        var maxTerminationResistance: String?

        // Parse header information
        let headerPattern =
            "<RBSTerminateContext\\|\\s*domain:(\\d+)\\s+code:(0x[A-F0-9]+)\\s+explanation:(.+?)(?=\\nProcessVisibility:|\\n[A-Z])"
        if let headerMatch = try matchRegex(pattern: headerPattern, in: logEntry, options: [.dotMatchesLineSeparators]) {
            domain = Int(headerMatch[1])
            code = headerMatch[2]
            explanation = headerMatch[3].trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse app information from explanation
            if let explanation = explanation {
                let appPattern = "app<([^(]+)\\(([^)]+)\\)>:(\\d+)"
                if let appMatch = try matchRegex(pattern: appPattern, in: explanation) {
                    appInfo = TerminationReason.AppInfo(
                        bundleId: appMatch[1],
                        uuid: appMatch[2],
                        pid: Int(appMatch[3])
                    )
                }

                // Extract timeout information
                let timeoutPattern = "time allowance of ([\\d.]+) seconds"
                if let timeoutMatch = try matchRegex(pattern: timeoutPattern, in: explanation) {
                    timeout = Double(timeoutMatch[1])
                }
            }
        }

        // Extract ProcessVisibility
        let visibilityPattern = "ProcessVisibility:\\s*(.+)"
        if let visibilityMatch = try matchRegex(pattern: visibilityPattern, in: logEntry) {
            processVisibility = visibilityMatch[1].trimmingCharacters(in: .whitespaces)
        }

        // Extract ProcessState
        let statePattern = "ProcessState:\\s*(.+)"
        if let stateMatch = try matchRegex(pattern: statePattern, in: logEntry) {
            processState = stateMatch[1].trimmingCharacters(in: .whitespaces)
        }

        // Extract WatchdogEvent
        let watchdogEventPattern = "WatchdogEvent:\\s*(.+)"
        if let watchdogEventMatch = try matchRegex(pattern: watchdogEventPattern, in: logEntry) {
            watchdogEvent = watchdogEventMatch[1].trimmingCharacters(in: .whitespaces)
        }

        // Extract WatchdogVisibility
        let watchdogVisibilityPattern = "WatchdogVisibility:\\s*(.+)"
        if let watchdogVisibilityMatch = try matchRegex(pattern: watchdogVisibilityPattern, in: logEntry) {
            watchdogVisibility = watchdogVisibilityMatch[1].trimmingCharacters(in: .whitespaces)
        }

        // Extract CPU Statistics
        let cpuStatsPattern = "WatchdogCPUStatistics:\\s*\\(\\s*\\n\"([^\"]+)\",\\s*\\n\"([^\"]+)\"\\s*\\n\\)"
        if let cpuStatsMatch = try matchRegex(
            pattern: cpuStatsPattern, in: logEntry, options: [.dotMatchesLineSeparators])
        {

            // Parse total CPU time
            let totalCpuPattern =
                "Elapsed total CPU time \\(seconds\\): ([\\d.]+) \\(user ([\\d.]+), system ([\\d.]+)\\), (\\d+)% CPU"
            if let totalCpuMatch = try matchRegex(pattern: totalCpuPattern, in: cpuStatsMatch[1]) {
                let totalCpuTime = Double(totalCpuMatch[1])
                let userTime = Double(totalCpuMatch[2])
                let systemTime = Double(totalCpuMatch[3])
                let totalCpuPercent = Int(totalCpuMatch[4])

                // Parse application CPU time
                let appCpuPattern = "Elapsed application CPU time \\(seconds\\): ([\\d.]+), (\\d+)% CPU"
                var appCpuTime: Double?
                var appCpuPercent: Int?

                if let appCpuMatch = try matchRegex(pattern: appCpuPattern, in: cpuStatsMatch[2]) {
                    appCpuTime = Double(appCpuMatch[1])
                    appCpuPercent = Int(appCpuMatch[2])
                }

                cpuStats = TerminationReason.WatchdogInfo.CPUStatistics(
                    totalCpuTime: totalCpuTime,
                    userTime: userTime,
                    systemTime: systemTime,
                    totalCpuPercent: totalCpuPercent,
                    appCpuTime: appCpuTime,
                    appCpuPercent: appCpuPercent
                )
            }
        }

        // Extract Thermal Information
        let thermalPattern =
            "ThermalInfo:\\s*\\(\\s*\\n\"Thermal Level: (\\d+)\",\\s*\\n\"Thermal State: ([^\"]+)\"\\s*\\n\\)"
        if let thermalMatch = try matchRegex(
            pattern: thermalPattern, in: logEntry, options: [.dotMatchesLineSeparators])
        {
            thermalLevel = Int(thermalMatch[1])
            thermalState = thermalMatch[2]
        }

        // Extract reportType
        let reportTypePattern = "reportType:([^\\s>]+)"
        if let reportTypeMatch = try matchRegex(pattern: reportTypePattern, in: logEntry) {
            reportType = reportTypeMatch[1]
        }

        // Extract maxTerminationResistance
        let terminationResistancePattern = "maxTerminationResistance:([^>]+)>"
        if let terminationResistanceMatch = try matchRegex(pattern: terminationResistancePattern, in: logEntry) {
            maxTerminationResistance = terminationResistanceMatch[1]
        }

        let watchdogInfo = TerminationReason.WatchdogInfo(
            event: watchdogEvent,
            visibility: watchdogVisibility,
            cpuStatistics: cpuStats
        )

        let thermal = TerminationReason.ThermalInfo(
            level: thermalLevel,
            state: thermalState
        )

        return TerminationReason(
            domain: domain,
            code: code,
            explanation: explanation,
            app: appInfo,
            timeout: timeout,
            processVisibility: processVisibility,
            processState: processState,
            watchdog: watchdogInfo,
            thermal: thermal,
            reportType: reportType,
            maxTerminationResistance: maxTerminationResistance
        )
    }

    /// Helper function to match regex patterns
    private static func matchRegex(pattern: String, in string: String, options: NSRegularExpression.Options = []) throws
        -> [String]?
    {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let nsString = string as NSString
            let range = NSRange(location: 0, length: nsString.length)

            guard let match = regex.firstMatch(in: string, options: [], range: range) else {
                return nil
            }

            var results: [String] = []
            for i in 0..<match.numberOfRanges {
                let range = match.range(at: i)
                if range.location != NSNotFound {
                    results.append(nsString.substring(with: range))
                } else {
                    results.append("")
                }
            }
            return results
        } catch {
            throw ParseError.regexError("Failed to create regex with pattern: \(pattern)")
        }
    }

    /// Format parsed data as a human-readable summary
    /// - Parameter context: The parsed RBSTerminationContext
    /// - Returns: Formatted summary string
    static func formatSummary(_ context: TerminationReason) -> String {
        var lines: [String] = []

        lines.append("=== RBS Termination Context ===")
        lines.append("App: \(context.app.bundleId ?? "Unknown") (PID: \(context.app.pid?.description ?? "Unknown"))")
        lines.append("Reason: \(context.explanation ?? "Unknown")")
        lines.append("Domain: \(context.domain?.description ?? "Unknown"), Code: \(context.code ?? "Unknown")")
        lines.append("")

        lines.append("Process State:")
        lines.append("  Visibility: \(context.processVisibility ?? "Unknown")")
        lines.append("  State: \(context.processState ?? "Unknown")")
        lines.append("")

        lines.append("Watchdog Information:")
        lines.append("  Event: \(context.watchdog.event ?? "Unknown")")
        lines.append("  Visibility: \(context.watchdog.visibility ?? "Unknown")")
        lines.append("  Timeout: \(context.timeout?.description ?? "Unknown")s")
        lines.append("")

        lines.append("CPU Statistics:")
        let cpu = context.watchdog.cpuStatistics
        lines.append(
            "  Total CPU Time: \(cpu.totalCpuTime?.description ?? "Unknown")s (\(cpu.totalCpuPercent?.description ?? "Unknown")%)"
        )
        lines.append("  User Time: \(cpu.userTime?.description ?? "Unknown")s")
        lines.append("  System Time: \(cpu.systemTime?.description ?? "Unknown")s")
        lines.append(
            "  App CPU Time: \(cpu.appCpuTime?.description ?? "Unknown")s (\(cpu.appCpuPercent?.description ?? "Unknown")%)"
        )
        lines.append("")

        lines.append("Thermal Information:")
        lines.append("  Level: \(context.thermal.level?.description ?? "Unknown")")
        lines.append("  State: \(context.thermal.state ?? "Unknown")")
        lines.append("")

        lines.append("Report Type: \(context.reportType ?? "Unknown")")
        lines.append("Max Termination Resistance: \(context.maxTerminationResistance ?? "Unknown")")

        return lines.joined(separator: "\n")
    }
}
