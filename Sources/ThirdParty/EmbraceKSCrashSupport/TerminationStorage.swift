//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
    import EmbraceTerminations
#endif

// MARK: - Swift Wrapper

/// Swift-friendly wrapper for the C termination storage API.
extension TerminationStorage {

    /// Mutate the shared termination storage, optionally avoiding locks for unsafe contexts.
    /// Mirrors `EMBTerminationStorageUpdate`.
    /// - Parameters:
    ///   - canLock: Pass `false` when calling from a signal/unsafe context.
    ///   - body: A closure to mutate the storage in-place. If `nil`, the function ensures storage is initialized.
    public static func update(canLock: Bool, _ body: ((inout TerminationStorage) -> Void)?) {
        EMBTerminationStorageUpdate(canLock) { storage in
            body?(&storage.pointee)
        }
    }

    /// Retrieve a snapshot of storage for an identifier.
    /// - Parameters:
    ///   - identifier: The identifier to query.
    /// - Returns: The storage if present, otherwise `nil`.
    public static func get(identifier: String) -> TerminationStorage? {
        var storage = TerminationStorage()
        let ok = EMBTerminationStorageForIdentifier(identifier, &storage)
        return ok ? storage : nil
    }

    /// Remove the storage associated with an identifier.
    /// - Parameter identifier: The identifier whose record should be removed.
    /// - Returns: `true` if a record was removed; `false` if none existed.
    @discardableResult
    public static func remove(identifier: String) -> Bool {
        EMBTerminationStorageRemoveForIdentifier(identifier)
    }

    /// All known identifiers with stored records.
    public static func identifiers() -> [String] {
        EMBTerminationStorageGetIdentifiers()
    }

    /// Convenience: Get a decoded dictionary for an identifier.
    /// - Parameter identifier: The identifier to decode.
    /// - Returns: A dictionary of attributes, or `nil` if no record exists.
    public static func dictionary(identifier: String) -> [String: TerminationAttributeValue]? {
        guard let storage = get(identifier: identifier) else { return nil }
        return storage.toDictionary()
    }
}

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

extension TerminationStorage {

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
