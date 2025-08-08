//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if canImport(MetricKit)
    import MetricKit
#endif

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

// MARK: - MetricKit Extensions

#if os(iOS)

    @available(iOS 14.0, *)
    extension MXCrashDiagnostic {

        var crashSignal: CrashSignal? {
            if let sig = signal as? Int {
                return CrashSignal(rawValue: sig)
            }
            return nil
        }

        func buildEmbraceCrashReport(
            sessionId: String?,
            timestamp: Date,
            logger: MetricKitReporterLogger
        ) -> EmbraceCrashReport? {
            logger.info("buildEmbraceCrashReport")

            guard let loadedReport = buildKSCrashReport(sessionId: sessionId, timestamp: timestamp, logger: logger)
            else {
                logger.error("Failed to buildKSCrashReport for session \(String(describing: sessionId))")
                return nil
            }

            // here's we're going to try and find if we have a threadcrumb with the session id in it.
            // if we find one, we'll insert this new data.
            var foundSessionId: String?
            var foundSdk: String?

            // we're looking for a thread with 39 frames.
            // `semaphore_wait_trap`
            // `_dispatch_sema4_wait`
            // `_dispatch_semaphore_wait_slow`
            // `__impact_threadcrumb_end__`
            // => ... 32 frames of `__impact__<N>__` for the GUID of the session it was part of (no hyphens).
            // `__impact_threadcrumb_start__`
            // `_pthread_start`
            // `thread_start`
            if let sessionIdThread = loadedReport.crash.threads.first(where: { $0.backtrace.contents.count == 39 }) {

                logger.info("found threadcrumb for session")

                // get the hash of the thread
                // we're only interested in the actual guid part
                var combinedHash: UInt64 = 0
                for (j, i) in (4...35).enumerated() {
                    let frame = sessionIdThread.backtrace.contents[i]
                    let addr: UInt64 = frame.instructionAddr
                    logger.info("\(j) => frame addr: \(addr)")
                    let shift = UInt64((j % 63) + 1)  // use zero-based index
                    let rotated = (addr << shift) | (addr >> (64 - shift))
                    combinedHash ^= rotated
                }
                let filename = String(format: "%016llx.stacksym", combinedHash)
                if let url = try? FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )
                .appendingPathComponent("ThreadcrumbSymbols").appendingPathComponent(filename) {
                    if let contents = try? String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines) {
                        if !contents.isEmpty {
                            foundSessionId = contents[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if contents.count > 1 {
                            foundSdk = contents[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else {
                        logger.error("Cound not load session symbols at \(filename)")
                    }
                } else {
                    logger.error("Cound not find session symbols at \(filename)")
                }

            } else {
                logger.error(
                    "Didn't find the session id threadcrumb, will use last session id \(String(describing: sessionId))")
            }

            let report = KarlCrashReport(
                binaryImages: loadedReport.binaryImages,
                crash: loadedReport.crash,
                report: loadedReport.report,
                system: loadedReport.system,
                user: KarlCrashReport.User(
                    sid: foundSessionId ?? loadedReport.user.sid,
                    sdk: foundSdk ?? loadedReport.user.sdk
                )
            )

            // encode it as a JSON string
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                let microseconds = Int64(date.timeIntervalSince1970 * 1_000_000)
                try container.encode(microseconds)
            }
            encoder.keyEncodingStrategy = .convertToSnakeCase
            guard let data = try? encoder.encode(report) else {
                logger.error("Error encoding KarlCrashReport for MetricKit")
                return nil
            }
            guard let payload = String(data: data, encoding: .utf8) else {
                logger.error("Error stringifying payload")
                return nil
            }

            return EmbraceCrashReport(
                payload: payload,
                provider: "kscrash",
                internalId: nil,
                sessionId: sessionId,
                timestamp: timestamp,
                signal: crashSignal
            )
        }

        func buildKSCrashReport(sessionId: String?, timestamp: Date, logger: MetricKitReporterLogger)
            -> KarlCrashReport?
        {

            let diagnostic: CrashDiagnostic
            do {
                try diagnostic = CrashDiagnostic.from(jsonRepresentation())
            } catch {
                logger.error("CrashDiagnostic.from error \(error)")
                return nil
            }

            return KarlCrashReport(
                binaryImages: diagnostic.callStackTree.binaryImages,
                crash: KarlCrashReport.Crash(
                    diagnosis: CrashDiagnosisFormatter().diagnosis(from: diagnostic),
                    error: KarlCrashReport.Crash.Error(
                        mach: KarlCrashReport.Crash.Error.Mach(
                            code: exceptionCode as? Int64,  // KERN_INVALID_ADDRESS
                            codeName: exceptionCode?.stringValue,
                            exception: machException?.rawValue,  // EXC_BAD_ACCESS
                            exceptionName: machException?.name,
                            subcode: nil
                        ),
                        signal: KarlCrashReport.Crash.Error.Signal(
                            code: nil,
                            codeName: nil,  // kssignal_signalCodeName
                            signal: signal as? Int,
                            name: crashSignal?.stringValue  // kssignal_signalName
                        ),
                        nsexception: KarlCrashReport.Crash.Error.NSException(
                            name: nsExceptionName,
                            userInfo: nsExceptionMessage
                        ),
                        cppException: KarlCrashReport.Crash.Error.CPPException(
                            name: nil  // no cpp in MetricKit
                        ),
                        type: karlExceptionType,
                        reason: nil
                    ),
                    threads: diagnostic.callStackTree.threads
                ),
                report: KarlCrashReport.Report(
                    id: UUID().uuidString,
                    timestamp: timestamp,
                    type: "standard"
                ),
                system: KarlCrashReport.System(
                    CFBundleIdentifier: diagnostic.metaData.bundleIdentifier,
                    CFBundleShortVersionString: diagnostic.metaData.appVersion,
                    CFBundleVersion: diagnostic.metaData.appBuildVersion,
                    appUuid: diagnostic.callStackTree.mainBinaryImageUUID ?? UUID().uuidString,  // UUID of the app binary
                    applicationStats: KarlCrashReport.System.ApplicationStats(
                        applicationActive: true,
                        ApplicationInForeground: true
                    ),
                    osVersion: operatingSystemBuild,  // 22F76
                    systemVersion: operatingSystemVersion  // 18.5
                ),
                user: KarlCrashReport.User(
                    sid: sessionId,
                    sdk: nil
                )
            )
        }

        var machException: MachException? {
            if let type = exceptionType as? Int64 {
                return MachException(rawValue: type)
            }
            return nil
        }

        var nsExceptionName: String? {
            if #available(iOS 17.0, macOS 14.0, *) {
                return exceptionReason?.exceptionName
            }
            return nil
        }

        var nsExceptionMessage: String? {
            if #available(iOS 17.0, macOS 14.0, *) {
                return exceptionReason?.composedMessage
            }
            return nil
        }

        var nsExceptionType: String? {
            if #available(iOS 17.0, macOS 14.0, *) {
                return exceptionReason?.exceptionType
            }
            return nil
        }

        var karlExceptionType: String {
            if nsExceptionName != nil {
                return "nsexception"
            }

            if exceptionType != nil {
                return "mach"
            }

            return "signal"
        }

        func _matchOSVersion(from input: String) -> (version: String, build: String?)? {

            let pattern = "(?:iPhone|iPad|iOS) OS (\\d+(?:\\.\\d+)*)(?: \\(([^)]+)\\))?"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return nil
            }

            let range = NSRange(input.startIndex..<input.endIndex, in: input)
            guard let match = regex.firstMatch(in: input, options: [], range: range) else {
                return nil
            }

            guard let versionRange = Range(match.range(at: 1), in: input) else {
                return nil
            }

            let version = String(input[versionRange])
            var build: String?

            if match.numberOfRanges > 2,
                let buildRange = Range(match.range(at: 2), in: input)
            {
                build = String(input[buildRange])
            }

            return (version, build)
        }

        var operatingSystemVersion: String? {
            _matchOSVersion(from: metaData.osVersion)?.version
        }

        var operatingSystemBuild: String? {
            _matchOSVersion(from: metaData.osVersion)?.build
        }

    }
#endif

struct CrashDiagnostic: Codable {

    let version: String
    let callStackTree: CallStackTree
    let metaData: DiagnosticMetaData

    enum CodingKeys: String, CodingKey {
        case version
        case callStackTree
        case metaData = "diagnosticMetaData"
    }

    static func from(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = .current
        formatter.timeZone = .current
        decoder.dateDecodingStrategy = .formatted(formatter)
        return try decoder.decode(Self.self, from: data)
    }

    static func with(_ data: Data) -> Self? {
        do {
            return try from(data)
        } catch {
            print("\(error)")
        }
        return nil
    }

    struct DiagnosticMetaData: Codable {
        let platformArchitecture: String
        let terminationReason: String?

        var terminationReasonCode: String? {
            guard let reason = terminationReason else {
                return nil
            }
            do {
                return try TerminationReasonParser.parse(reason).code
            } catch {}
            return nil
        }

        struct Signpost: Codable {
            let beginTimeStamp: Date
            let endTimeStamp: Date?
            let isInterval: Bool
            let name: String
            let category: String
            let subsystem: String
        }
        let signpostData: [Signpost]?

        let exceptionType: Int64
        let appBuildVersion: String
        let isTestFlightApp: Bool
        let osVersion: String
        let bundleIdentifier: String
        let deviceType: String
        let exceptionCode: Int64
        let virtualMemoryRegionInfo: String?
        let signal: Int64
        let regionFormat: String
        let appVersion: String
        let pid: pid_t
        let lowPowerModeEnabled: Bool

        var machException: MachException? {
            if exceptionType > 0 {
                return MachException(rawValue: exceptionType)
            }
            return nil
        }

        var crashSignal: CrashSignal? {
            if signal > 0 {
                return CrashSignal(rawValue: Int(signal))
            }
            return nil
        }
    }

    struct CallStackTree: Codable {
        let callStackPerThread: Bool

        struct CallStack: Codable {
            let threadAttributed: Bool

            struct Frame: Codable {
                let binaryUUID: String
                let offsetIntoBinaryTextSegment: UInt64
                let sampleCount: Int
                let subFrames: [Frame]?
                let binaryName: String?
                let address: UInt64

                var frames: [Frame] {
                    subFrames?.reduce(into: [self]) { partialResult, frame in
                        partialResult.append(contentsOf: frame.frames)
                    } ?? [self]
                }

                var binaryImage: KarlCrashReport.BinaryImage? {
                    guard let binaryName else {
                        return nil
                    }
                    return KarlCrashReport.BinaryImage(
                        imageAddr: address - offsetIntoBinaryTextSegment,
                        imageSize: 0,
                        name: binaryName,
                        uuid: binaryUUID
                    )
                }

                var binaryImages: [KarlCrashReport.BinaryImage] {
                    return
                        (subFrames?.reduce(into: [binaryImage]) { partialResult, frame in
                            partialResult.append(contentsOf: frame.binaryImages)
                        } ?? [binaryImage]).compactMap { $0 }
                }
            }
            let callStackRootFrames: [Frame]

            func flattenedAsThread(index: Int64) -> KarlCrashReport.Crash.Thread? {

                let contents: [KarlCrashReport.Crash.Thread.Backtrace.Frame]? = callStackRootFrames.first?.frames
                    .compactMap {
                        guard let bin = $0.binaryName else {
                            return nil
                        }
                        return KarlCrashReport.Crash.Thread.Backtrace.Frame(
                            instructionAddr: $0.address,
                            objectAddr: $0.address - $0.offsetIntoBinaryTextSegment,
                            objectName: bin,
                            symbolAddr: $0.offsetIntoBinaryTextSegment,
                            symbolName: nil
                        )
                    }

                // we don't need to show fully empty threads
                if let contents, contents.isEmpty {
                    return nil
                }

                return KarlCrashReport.Crash.Thread(
                    id: index,
                    name: nil,
                    backtrace: KarlCrashReport.Crash.Thread.Backtrace(
                        contents: contents ?? []
                    ),
                    crashed: threadAttributed
                )
            }
        }
        let callStacks: [CallStack]

        static func from(_ data: Data) -> Self? {
            do {
                return try JSONDecoder().decode(Self.self, from: data)
            } catch {
                print("\(error)")
            }
            return nil
        }

        var binaryImages: [KarlCrashReport.BinaryImage] {
            var lowestAddrByUUID: [String: UInt64] = [:]
            var highestAddrByUUID: [String: UInt64] = [:]
            var imageMap: [String: KarlCrashReport.BinaryImage] = [:]

            for callstack in callStacks {
                for rootFrames in callstack.callStackRootFrames {
                    for f in rootFrames.frames {

                        guard let image = f.binaryImage else {
                            continue
                        }

                        // Track lowest address
                        let addr = image.imageAddr
                        if let existing = lowestAddrByUUID[image.uuid] {
                            lowestAddrByUUID[image.uuid] = min(existing, addr)
                        } else {
                            lowestAddrByUUID[image.uuid] = addr
                        }

                        // Track highest address
                        let maxAddress = f.address
                        if let existing = highestAddrByUUID[image.uuid] {
                            highestAddrByUUID[image.uuid] = max(existing, maxAddress)
                        } else {
                            highestAddrByUUID[image.uuid] = maxAddress
                        }

                        imageMap[image.uuid] = image
                    }
                }
            }

            return imageMap.values.compactMap {
                guard let low = lowestAddrByUUID[$0.uuid], let high = highestAddrByUUID[$0.uuid] else {
                    return nil
                }
                return KarlCrashReport.BinaryImage(
                    imageAddr: low,
                    imageSize: high - low + 1,
                    name: $0.name,
                    uuid: $0.uuid
                )
            }
            .sorted { $0.imageAddr < $1.imageAddr }
        }

        var threads: [KarlCrashReport.Crash.Thread] {

            assert(callStackPerThread)

            var threads: [KarlCrashReport.Crash.Thread] = []
            var index: Int64 = 0
            for stack in callStacks {
                if let thread = stack.flattenedAsThread(index: index) {
                    threads.append(thread)
                }
                index += 1
            }

            return threads
        }

        var mainBinaryImageUUID: String? {
            nil
        }
    }
}

struct KarlCrashReport: Codable {

    struct BinaryImage: Codable, Hashable {
        let imageAddr: UInt64
        let imageSize: UInt64
        let name: String
        let uuid: String
    }
    let binaryImages: [BinaryImage]

    struct Crash: Codable {
        let diagnosis: String?

        struct Error: Codable {

            struct Mach: Codable {
                let code: Int64?
                let codeName: String?
                let exception: Int64?
                let exceptionName: String?
                let subcode: UInt64?
            }
            let mach: Mach

            struct Signal: Codable {
                let code: Int?
                let codeName: String?
                let signal: Int?
                let name: String?
            }
            let signal: Signal

            struct NSException: Codable {
                let name: String?
                let userInfo: String?
            }
            let nsexception: NSException

            struct CPPException: Codable {
                let name: String?
            }
            let cppException: CPPException

            let type: String
            let reason: String?
        }
        let error: Error

        struct Thread: Codable {
            let id: Int64
            let name: String?

            struct Backtrace: Codable {
                struct Frame: Codable {
                    let instructionAddr: UInt64
                    let objectAddr: UInt64
                    let objectName: String
                    let symbolAddr: UInt64
                    let symbolName: String?
                }
                let contents: [Frame]
            }
            let backtrace: Backtrace
            let crashed: Bool

        }
        let threads: [Thread]
    }
    let crash: Crash

    struct Report: Codable {
        let id: String
        let timestamp: Date  // microseconds since unix epoch
        let type: String
    }
    let report: Report

    struct System: Codable {
        let CFBundleIdentifier: String?
        let CFBundleShortVersionString: String?
        let CFBundleVersion: String?
        let appUuid: String?

        struct ApplicationStats: Codable {
            let applicationActive: Bool
            let ApplicationInForeground: Bool
        }
        let applicationStats: ApplicationStats
        let osVersion: String?
        let systemVersion: String?
    }
    let system: System

    struct User: Codable {
        let sid: String?
        let sdk: String?

        enum CodingKeys: String, CodingKey {
            case sid = "emb-sid"
            case sdk = "emb-sdk"
        }
    }
    let user: User
}
