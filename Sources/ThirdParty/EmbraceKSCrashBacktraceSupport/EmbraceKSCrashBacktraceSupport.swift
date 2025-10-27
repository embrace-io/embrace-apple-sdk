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

public class KSCrashBacktracing: Backtracer, Symbolicator {

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
            let count = captureBacktrace(thread: thread, addresses: &addresses, count: Int32(entries))
            addresses = Array(addresses[0..<Int(count)])
        }
        return addresses
    }

    public func resolve(address: UInt) -> SymbolicatedFrame? {

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
