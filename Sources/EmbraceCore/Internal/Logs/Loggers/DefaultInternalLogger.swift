//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Darwin
import Foundation
import OSLog

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceOTelInternal
    import EmbraceStorageInternal
    import EmbraceConfigInternal
    import EmbraceConfiguration
#endif

/// Internal logger that writes `.startup` and `.critical` lines straight to disk so a
/// previous run's critical context can be uploaded on the next launch.
///
/// File layout uses two paths under `EmbraceFileSystem.rootURL()`:
///   - `pending-logs`  — staging file. Receives `.startup` lines.
///   - `critical-logs` — upload file. Created by renaming `pending-logs` the first time
///                       a `.critical` is logged. All subsequent custom-export lines
///                       append here.
///
/// On next launch, `UnsentDataHandler.sendCriticalLogs` uploads `critical-logs` and
/// deletes any orphan `pending-logs`. If no `.critical` ever fired, no file is uploaded.
///
/// Writes use POSIX `open`/`write`/`fsync`/`close` directly instead of `FileHandle`.
/// POSIX returns error codes; `FileHandle`'s legacy API raises `NSException` on failure,
/// which Swift `try/catch` cannot intercept and historically tripped a recursive crash
/// path under memory pressure.
class DefaultInternalLogger: BaseInternalLogger {

    let subsystem: String = "com.embrace.logger"
    let category: String = "internal"
    let customExportByteCountLimit: Int

    let pendingFilePath: URL?
    let criticalFilePath: URL?

    let osLogger: OSLog

    private struct State {
        var fileDescriptor: Int32 = -1
        var criticalFired: Bool = false
        var bytesWritten: Int = 0
        var limitReached: Bool = false
    }

    private let state = EmbraceMutex(State())

    init(
        pendingFilePath: URL?,
        criticalFilePath: URL?,
        exportByCountLimit: Int = 1000
    ) {
        self.pendingFilePath = pendingFilePath
        self.criticalFilePath = criticalFilePath
        self.customExportByteCountLimit = exportByCountLimit

        osLogger = OSLog(subsystem: subsystem, category: category)

        super.init()
    }

    deinit {
        let fd = state.unsafeValue.fileDescriptor
        if fd >= 0 {
            close(fd)
        }
    }

    override func output(_ message: String, level: LogLevel, customExport: Bool) {

        os_log(level.osLogType, log: osLogger, "%{public}@", message)

        guard customExport else { return }

        let line = "[\(Self.timestampFormatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        state.withLock { state in
            guard !state.limitReached else { return }

            if level == .critical && !state.criticalFired {
                promote(state: &state)
            }

            if state.fileDescriptor < 0 {
                let target = state.criticalFired ? criticalFilePath : pendingFilePath
                guard let url = target else { return }
                openFile(at: url, state: &state)
            }

            let fd = state.fileDescriptor
            guard fd >= 0 else { return }

  
            let available = customExportByteCountLimit - state.bytesWritten
            if available <= 0 {
                state.limitReached = true
                return
            }
            let chunk = data.prefix(available)

            let written = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int in
                guard let base = buffer.baseAddress else { return -1 }
                return write(fd, base, buffer.count)
            }

            if written < 0 {
                print("Error writing critical logs file: errno \(errno)")
                return
            }

            state.bytesWritten += written

            if level == .critical {
                _ = fsync(fd)
            }
        }
    }

    /// Promotes the staging file to the upload path and re-opens for append.
    /// Must be called while holding the state lock.
    private func promote(state: inout State) {
        guard let criticalURL = criticalFilePath else {
            // Without a critical URL we cannot promote; keep writing to pending if possible.
            state.criticalFired = true
            return
        }

        if state.fileDescriptor >= 0 {
            close(state.fileDescriptor)
            state.fileDescriptor = -1
        }

        // Defensive: a stale critical-logs from a prior run should already have been
        // consumed at boot time. Remove it if it somehow still exists so the rename
        // doesn't fail with "file exists".
        try? FileManager.default.removeItem(at: criticalURL)

        if let pendingURL = pendingFilePath,
            FileManager.default.fileExists(atPath: pendingURL.path)
        {
            do {
                try FileManager.default.moveItem(at: pendingURL, to: criticalURL)
            } catch {
                // Fall through: open critical-logs directly. We lose the prior startup
                // trail, but still capture the .critical line that triggered promotion.
                print("Error promoting pending logs to critical logs: \(error.localizedDescription)")
            }
        }

        state.criticalFired = true
    }

    /// Opens (creating if needed) the file at `url` for append and stores the file descriptor.
    /// Must be called while holding the state lock.
    private func openFile(at url: URL, state: inout State) {
        let parent = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let fd = url.path.withCString { path -> Int32 in
            open(path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        }

        guard fd >= 0 else {
            print("Error opening critical logs file: errno \(errno)")
            return
        }

        let endOffset = lseek(fd, 0, SEEK_END)
        state.fileDescriptor = fd
        state.bytesWritten = endOffset >= 0 ? Int(endOffset) : 0
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter
    }()
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
