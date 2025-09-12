//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

struct MetricKitDiagnosticReport: Codable {

    let version: String
    let callStackTree: CallStackTree
    let metaData: DiagnosticMetaData

    enum CodingKeys: String, CodingKey {
        case version
        case callStackTree
        case metaData = "diagnosticMetaData"
    }

    struct DiagnosticMetaData: Codable {
        let platformArchitecture: String
        let terminationReason: String?

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
            }
            let callStackRootFrames: [Frame]
        }
        let callStacks: [CallStack]
    }
}

/// Extensions

extension MetricKitDiagnosticReport {

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
}

extension MetricKitDiagnosticReport.DiagnosticMetaData {

    var terminationReasonCode: String? {
        guard let reason = terminationReason else {
            return nil
        }
        do {
            return try TerminationReasonParser.parse(reason).code
        } catch {}
        return nil
    }

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

extension MetricKitDiagnosticReport.CallStackTree {

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

extension MetricKitDiagnosticReport.CallStackTree.CallStack {

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

extension MetricKitDiagnosticReport.CallStackTree.CallStack.Frame {

    var frames: [Self] {
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
