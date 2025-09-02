//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OSLog

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
#endif

class DefaultInternalLogger: BaseInternalLogger {

    let subsystem: String = "com.embrace.logger"
    let defaultCategory: String = "internal"
    let customExportCategory: String
    let customExportByteCountLimit: Int

    let exportFilePath: URL?
    let defaultLogger: OSLog
    let customExportLogger: OSLog

    private var exporting: Bool = false
    private var exportByteCount: Int = 0
    private var exportLimitReached: Bool = false
    private var lastExportDate: Date?

    internal let queue: DispatchableQueue

    init(exportFilePath: URL?, exportByCountLimit: Int = 1000, exportCategory: String = "custom-export") {
        self.exportFilePath = exportFilePath
        self.customExportByteCountLimit = exportByCountLimit
        self.customExportCategory = exportCategory

        defaultLogger = OSLog(subsystem: subsystem, category: defaultCategory)
        customExportLogger = OSLog(subsystem: subsystem, category: customExportCategory)

        queue = .with(label: "com.embrace.logger.export")

        super.init()
    }

    override func output(_ message: String, level: LogLevel, customExport: Bool) {

        if customExport {
            os_log(level.osLogType, log: customExportLogger, "%{public}@", message)
        } else {
            os_log(level.osLogType, log: defaultLogger, "%{public}@", message)
        }

        if #available(iOS 15.0, tvOS 15.0, macOS 10, watchOS 8.0, *) {
            if level == .critical {
                export()
            }
        }
    }

    @available(iOS 15.0, tvOS 15.0, macOS 10, watchOS 8.0, *)
    /// Exports all logs in the `custom-export` category to a file.
    /// Subsequent calls append any new entries created since the last call into the file.
    func export() {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            guard let fileURL = self.exportFilePath,
                self.exporting == false,
                self.exportLimitReached == false
            else {
                return
            }

            self.exporting = true
            defer { self.exporting = false }

            do {
                // create OSLogStore for the current process
                let store = try OSLogStore(scope: .currentProcessIdentifier)

                // calculate starting position so we only fetch logs we haven't exported yet
                var position: OSLogPosition
                if let lastExportDate = self.lastExportDate {
                    position = store.position(date: lastExportDate.addingTimeInterval(0.01))
                } else {
                    position = store.position(timeIntervalSinceLatestBoot: 0)
                }

                // fetch log entries
                let entries: [OSLogEntryLog] =
                    try store
                    .getEntries(at: position)
                    .compactMap { $0 as? OSLogEntryLog }
                    .filter { $0.subsystem == self.subsystem && $0.category == self.customExportCategory }

                // create file if needed
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    let rootURL = fileURL.deletingLastPathComponent()
                    try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }

                guard let file = FileHandle(forWritingAtPath: fileURL.path) else {
                    try? FileManager.default.removeItem(at: fileURL)
                    return
                }

                try file.seekToEnd()

                // write log lines
                for entry in entries {
                    let line = entry.formattedMessage + "\n"
                    guard let data = line.data(using: .utf8) else {
                        continue
                    }

                    // don't make the file too big
                    guard self.exportByteCount + data.count <= self.customExportByteCountLimit else {
                        self.exportLimitReached = true
                        break
                    }

                    try file.write(contentsOf: data)
                    self.exportByteCount += data.count
                }

                // save last entry date
                self.lastExportDate = entries.last?.date

                // close file
                try file.close()

            } catch {
                print("Error exporting internal logs!:\n\(error.localizedDescription)")
            }
        }
    }
}

extension LogLevel {
    var osLogType: OSLogType {
        switch self {
        case .trace, .debug:
            return OSLogType.debug
        case .info:
            return OSLogType.info
        case .warning, .error:
            return OSLogType.error
        case .critical:
            return OSLogType.fault
        default:
            return OSLogType.default
        }
    }
}

@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension OSLogEntryLog {
    var formattedMessage: String {
        "[\(date.formatted(date: .numeric, time: .complete))] \(composedMessage)"
    }
}
