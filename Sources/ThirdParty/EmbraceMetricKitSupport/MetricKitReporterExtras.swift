//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if canImport(MetricKit)
    import MetricKit
#endif

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceObjCUtilsInternal
    import EmbraceMetricKitSupportObjC
#endif

#if canImport(KSCrashRecording)
    import KSCrashRecording
#elseif canImport(KSCrash)
    import KSCrash
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
            var foundProcessId: String?

            // we're looking for a thread with 39 frames.
            // `semaphore_wait_trap`
            // `_dispatch_sema4_wait`
            // `_dispatch_semaphore_wait_slow`
            // `__impact_threadcrumb_end__`
            // => ... 32 frames of `__impact__<N>__` for the GUID of the session it was part of (no hyphens).
            // `__impact_threadcrumb_start__`
            // `_pthread_start`
            // `thread_start`
            var internalId: String?
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
                let iid = String(format: "%016llx", combinedHash)
                let filename = iid.appending(".stacksym")
                internalId = iid
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
                            foundProcessId = contents[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if contents.count > 2 {
                            foundSdk = contents[2].trimmingCharacters(in: .whitespacesAndNewlines)
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
            guard let data = try? KarlCrashReport.encoder.encode(report) else {
                logger.error("Error encoding KarlCrashReport for MetricKit")
                return nil
            }
            guard let payload = String(data: data, encoding: .utf8) else {
                logger.error("Error stringifying payload")
                return nil
            }

            return EmbraceCrashReport(
                payload: payload,
                provider: "metrickit_kscrash",
                internalId: internalId,
                sessionId: foundSessionId ?? report.user.sid,
                processId: foundProcessId,
                timestamp: timestamp,
                signal: crashSignal
            )
        }

        func buildKSCrashReport(sessionId: String?, timestamp: Date, logger: MetricKitReporterLogger)
            -> KarlCrashReport?
        {

            let diagnostic: MetricKitDiagnosticReport
            do {
                try diagnostic = MetricKitDiagnosticReport.from(jsonRepresentation())
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

/// Safely decode a fixed-size C char buffer (possibly not null-terminated) as UTF-8.
private func fixedCString<T>(cString: T) -> String {
    var copy = cString  // make a local so we can take an inout pointer
    return withUnsafePointer(to: &copy) { ptr in
        let byteCount = MemoryLayout<T>.size
        return ptr.withMemoryRebound(to: UInt8.self, capacity: byteCount) { u8 in
            let buf = UnsafeBufferPointer(start: u8, count: byteCount)
            let end = buf.firstIndex(of: 0) ?? byteCount
            return String(decoding: buf.prefix(end), as: UTF8.self)
        }
    }
}

extension EMBTerminationStorage {

    var processIdentifier: String {
        withUnsafePointer(to: uuid) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 16) { bytes in
                UUID(
                    uuid: (
                        bytes[0], bytes[1], bytes[2], bytes[3],
                        bytes[4], bytes[5], bytes[6], bytes[7],
                        bytes[8], bytes[9], bytes[10], bytes[11],
                        bytes[12], bytes[13], bytes[14], bytes[15]
                    )
                ).uuidString
            }
        }
    }

    var lastKnownDate: Date {
        let value = creationTimestampEpochMillis + (updateTimestampMonotonicMillis - creationTimestampMonotonicMillis)
        let seconds = Double(value) / 1000.0
        return Date(timeIntervalSince1970: seconds)
    }

    func toDictionary() -> [String: TerminationAttributeValue] {
        var dict: [String: TerminationAttributeValue] = [:]

        dict["magic"] = magic
        dict["version"] = version
        dict["creationTimestampMonotonicMillis"] = creationTimestampMonotonicMillis
        dict["creationTimestampEpochMillis"] = creationTimestampEpochMillis
        dict["updateTimestampMonotonicMillis"] = updateTimestampMonotonicMillis

        dict["uuid"] = processIdentifier
        dict["pid"] = pid
        dict["stackOverflow"] = stackOverflow != 0
        dict["address"] = address

        dict["cleanExitSet"] = cleanExitSet != 0
        dict["exitCalled"] = exitCalled != 0
        dict["quickExitCalled"] = quickExitCalled != 0
        dict["terminateCalled"] = terminateCalled != 0

        dict["exceptionSet"] = exceptionSet != 0
        dict["exceptionType"] = exceptionType  // keep raw type value
        dict["exceptionName"] = fixedCString(cString: exceptionName)
        dict["exceptionReason"] = fixedCString(cString: exceptionReason)
        dict["exceptionUserInfo"] = fixedCString(cString: exceptionUserInfo)

        dict["machExceptionSet"] = machExceptionSet != 0
        dict["machExceptionNumber"] = machExceptionNumber
        dict["machExceptionNumberName"] = MachException(rawValue: machExceptionNumber)?.name
        dict["machExceptionCode"] = machExceptionCode
        dict["machExceptionSubcode"] = machExceptionSubcode

        dict["signalSet"] = signalSet != 0
        dict["signalNumber"] = signalNumber
        dict["signalNumberName"] = CrashSignal(rawValue: Int(signalNumber))?.stringValue
        dict["signalCode"] = signalCode

        dict["appTransitionState"] = appTransitionState
        if let state = AppTransitionState(rawValue: appTransitionState) {
            dict["appTransitionStateName"] = String(cString: state.cString())
            dict["appTransitionStateIsUserPercetible"] = state.isUserPerceptible()
        }

        dict["memoryFootprint"] = memoryFootprint
        dict["memoryRemaining"] = memoryRemaining
        dict["memoryLimit"] = memoryLimit

        dict["memoryLevel"] = memoryLevel
        if let value = AppMemoryState(rawValue: UInt(memoryLevel)) {
            dict["memoryLevelName"] = String(cString: value.cString())
        }

        dict["memoryPressure"] = memoryPressure
        if let value = AppMemoryState(rawValue: UInt(memoryPressure)) {
            dict["memoryPressureName"] = String(cString: value.cString())
        }

        return dict
    }
}
