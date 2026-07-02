//
//  EmbraceARM64_32Helpers.swift
//  EmbraceIO
//
//

// watchOS uses ARM64_32 which are 64 bit instructions but 32 bit pointers. Some key differences include Ints being 32 bit vs 64 on ARM64 devices.
// 64 bit variables such as Int64 are supported but you need to use them as such.
// In order to keep compatibility with apple series 8 and below, and not add macro checks everywhere, we need to typealias our Int usage.
// Only relevant when using numbers in the 64 bit range.
// When specifying type attribute for storing in coredata however, it is necessary to do a platform type check and correctly use either `integer32AttributeType` or `integer64AttributeType`.

import Foundation

// MARK: - Platform-Specific Type Aliases
#if arch(arm64_32)
    public typealias EMBInt = Int64
    public typealias EMBUInt = UInt64
#else
    public typealias EMBInt = Int
    public typealias EMBUInt = UInt
#endif
