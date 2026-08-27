//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

#if !EMBRACE_COCOAPOD_BUILDING_SDK
    import EmbraceCommonInternal
#endif

#if canImport(KSCrash)
    import KSCrash
#else
    import KSCrashRecording
    @_exported import KSCrashDemangleFilter
#endif

package struct SymbolicatedFrame {
    package let returnAddress: UInt
    package let callInstruction: UInt
    package let symbolAddress: UInt
    package let symbolName: String?
    package let imageName: String?
    package let imageUUID: String?
    package let imageAddress: UInt
    package let imageSize: UInt64
}

public class KSCrashBacktracing {

    public init() {}

    public func backtrace(of thread: pthread_t) -> [UInt] {

        // In KSCrash there's a bug that causes a backtrace on the pthread_self
        // to not work. So for now we'll simply use `backtrace`
        // fix: https://github.com/kstenerud/KSCrash/pull/690

        let entries = 512
        var addresses: [UInt] = Array(repeating: 0, count: 512)

        if thread == pthread_self() {
            addresses = Thread.callStackReturnAddresses.compactMap { $0 as? UInt }
        } else {
            // `captureBacktrace` reaches KSCrash's binary-image cache; serialize against the
            // crash-reporter install and symbolication paths. See `KSCrashGlobalsLock`.
            let count = KSCrashGlobalsLock.withLock {
                captureBacktrace(thread: thread, addresses: &addresses, count: Int32(entries))
            }
            addresses = Array(addresses[0..<Int(count)])
        }
        return addresses
    }

    /// Fills `buffer` (which has room for `capacity` addresses) with the frame addresses of `thread`,
    /// returning the number of addresses written. Ordered from the top frame to the bottom.
    ///
    /// Unlike ``backtrace(of:)``, this returns nothing heap-allocated: the caller owns `buffer`. It
    /// exists so the walk can run while `thread` is **suspended** without the walker touching the
    /// heap — a `malloc` here can deadlock the whole process if the suspended thread holds the
    /// allocator lock.
    ///
    /// - Important: This implementation MUST remain allocation-free and async-signal-safe: no
    ///   `malloc`, no Obj-C/Swift runtime work, no lock acquisition. It is called between
    ///   `thread_suspend` and `thread_resume` of a thread that is not the caller. In particular it
    ///   must NOT take `KSCrashGlobalsLock` — doing so in-window would deadlock. That is safe here
    ///   because `ksbt_captureBacktrace` never reaches the binary-image cache (`ksbic_init` is only
    ///   reached via `ksbt_symbolicateAddress`), unlike ``backtrace(of:)`` and ``resolve(address:)``.
    /// - Parameters:
    ///   - thread: The target `pthread_t`. Must not be the calling thread (it is expected to be
    ///     suspended by the caller for the duration of the call). The `pthread_self()` workaround in
    ///     ``backtrace(of:)`` is intentionally NOT replicated here.
    ///   - buffer: Caller-owned storage for at least `capacity` addresses.
    ///   - capacity: The capacity of `buffer`, in elements.
    /// - Returns: The number of frame addresses written to `buffer` (`0...capacity`).
    package func backtrace(
        of thread: pthread_t,
        into buffer: UnsafeMutablePointer<UInt>,
        capacity: Int
    ) -> Int {
        // Alloc-free: `ksbt_captureBacktrace` fills the caller's buffer in place using a
        // stack-allocated machine context + stack cursor (no malloc, no runtime calls).
        return Int(captureBacktrace(thread: thread, addresses: buffer, count: Int32(capacity)))
    }

    package func resolve(address: UInt) -> SymbolicatedFrame? {

        // `symbolicate` (-> `ksbt_symbolicateAddress` -> `ksbic_init`) and the Swift demangler both
        // touch unsynchronized KSCrash globals; serialize against install/capture. See `KSCrashGlobalsLock`.
        KSCrashGlobalsLock.withLock {
            var result = SymbolInformation()
            guard symbolicate(address: UInt(address), result: &result) else {
                return nil
            }

            return SymbolicatedFrame(
                returnAddress: result.returnAddress,
                callInstruction: result.callInstruction,
                symbolAddress: result.symbolAddress,
                symbolName: result.symbolName.flatMap { backtraceDemangle(String(cString: $0)) },
                imageName: result.imageName.flatMap { String(cString: $0) },
                imageUUID: NSUUID(uuidBytes: result.imageUUID).uuidString,
                imageAddress: result.imageAddress,
                imageSize: result.imageSize
            )
        }
    }

    private func backtraceDemangle(_ symbol: String?) -> String {

        guard let symbol else { return "<unknown>" }

        // try simplified for the UI
        if let a2 = CrashReportFilterDemangle.demangledSwiftSymbol(symbol)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !a2.isEmpty
        {
            return a2
        }

        // full non-simplified demangle
        if let a3 = _swift_demangleImpl(symbol)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return a3
        }

        // cpp demangle
        if let a4 = CrashReportFilterDemangle.demangledCppSymbol(symbol)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !a4.isEmpty
        {
            return a4
        }

        // return the original, likely ObjC or something
        return symbol
    }
}

@_silgen_name("swift_demangle")
public func _stdlib_demangleImpl(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<CChar>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
) -> UnsafeMutablePointer<CChar>?

private func _swift_demangleImpl(_ symbol: String) -> String? {

    return symbol.utf8CString.withUnsafeBufferPointer { (mangledNameUTF8CStr) in
        let demangledNamePtr = _stdlib_demangleImpl(
            mangledName: mangledNameUTF8CStr.baseAddress,
            mangledNameLength: UInt(mangledNameUTF8CStr.count - 1),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0)

        guard let demangledNamePtr else {
            return nil
        }

        let demangledName = String(cString: demangledNamePtr)
        free(demangledNamePtr)
        return demangledName
    }
}
