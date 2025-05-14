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

@available(iOS 15.0, *)
class DefaultInternalLogger: BaseInternalLogger {

    let subsystem: String = "com.embrace.logger"
    let defaultCategory: String = "internal"
    let customExportCategory: String = "custom-export"

    @ThreadSafe
    var defaultLogger: Logger

    @ThreadSafe
    var customExportLogger: Logger

    let exportFilePath: URL?

    init(exportFilePath: URL?) {
        self.exportFilePath = exportFilePath
        defaultLogger = Logger(subsystem: subsystem, category: defaultCategory)
        customExportLogger = Logger(subsystem: subsystem, category: customExportCategory)

        super.init()
    }

    override func output(_ message: String, level: LogLevel, customExport: Bool) {

        if customExport {
            customExportLogger.log(level: level.osLogType, "\(message)")
        } else {
            defaultLogger.log(level: level.osLogType, "\(message)")
        }

        if level == .critical {
            export()
        }
    }

    func export() {
        guard let fileUrl = exportFilePath else {
            return
        }

        do {
            // fetch entries from OSLogStore
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 0)

            let entries: [String] = try store
                .getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == subsystem && $0.category == customExportCategory }
                .map { "[\($0.date.formatted(.iso8601))] \($0.composedMessage)" }

            // remove existing file, if any
            try? FileManager.default.removeItem(at: fileUrl)

            // write new log file
            let log = entries.joined(separator: "\n")
            try log.write(to: fileUrl, atomically: true, encoding: .utf8)

        } catch {
            print("Error exporting internal logs!:\n\(error.localizedDescription)")
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
