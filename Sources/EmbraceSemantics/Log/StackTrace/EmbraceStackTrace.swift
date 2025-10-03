//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

/// Class used to add custom stack traces to `EmbraceLogs`.
@objc
public class EmbraceStackTrace: NSObject {
    /// The maximum amount of characters a stack trace frame can have.
    private static let maximumFrameLength = 10000

    /// The maximum amount of frames we support in a stacktrace.
    private static let maximumAmountOfFrames = 200

    /// The captured stack frames, following the format of `Thread.callStackSymbols`.
    public private(set) var frames: [String]

    /// Initializes a `EmbraceStackTrace` with a given list of stack frames.
    ///
    /// Each frame is represented as a `String`, containing:
    /// - The frame index.
    /// - The binary name.
    /// - The memory address.
    /// - The symbol.
    /// - The offset within the symbol.
    ///
    /// Example format of _a single frame_:
    /// ```
    /// 2   EmbraceApp    0x0000000001234abc  -[MyClass myMethod] + 48
    /// ```
    ///
    /// - Parameter frames: An array of frames strings, following the format of `Thread.callStackSymbols`.
    /// - Throws: An `EmbraceStackTraceError.invalidFormat` if any of the frames are not in the expected format
    /// - Throws: An `EmbraceStackTraceError.frameIsTooLong` if any of the frames has more than the `maximumFrameLength` (10.000 characters).
    ///
    /// - Important: A stacktrace can't have more than `maximumAmountOfFrames` (200); if that happens, we'll trim the exceeding frames.
    @objc public init(frames: [String]) throws {
        let trimmedStackTrace = EmbraceStackTrace.trimStackTrace(frames)
        try EmbraceStackTrace.validateStackFrames(trimmedStackTrace)
        self.frames = trimmedStackTrace
    }

    private static func validateStackFrames(_ frames: [String]) throws {
        try frames.forEach {
            if $0.count >= maximumFrameLength {
                throw EmbraceStackTraceError.frameIsTooLong
            }
            if !isValidStackFrameFormat($0) {
                throw EmbraceStackTraceError.invalidFormat
            }
        }
    }

    /// Generates a stack trace with up to `maximumAmountOfFrames` frames.
    ///
    /// - Important: A stack trace can't have more than `maximumAmountOfFrames` (200);
    ///   if that happens, we'll trim the exceeding frames.
    /// - Returns: An array of stack frames as `String`.
    private static func trimStackTrace(_ stackFrames: [String]) -> [String] {
        return Array(stackFrames.prefix(maximumAmountOfFrames))
    }

    /// Validates if a given frame string follows the required format.
    /// - Parameter frame: a stack trace frame.
    /// - Returns: whether the format is valid or invalid.
    private static func isValidStackFrameFormat(_ frame: String) -> Bool {
        /*
         Regular expression pattern breakdown:
        
         ^\s*                   -> Allows optional leading spaces at the beginning
         (\d+)                  -> Captures the frame index (a sequence of digits)
         \s+                    -> One or more whitespaces
         ([^\s]+(?:\s+[^\s]+)*) -> Captures the module name, allowing spaces between words but not at the edges
         \s+                    -> One or more whitespaces
         (0x[0-9A-Fa-f]+)       -> Captures the memory address hex (must start with `0x`)
         \s+                    -> One or more whitespaces
         (\S.+?)                -> Captures the function/method symbol ensuring it's not empty (non-greedy/lazy)
         (?:\s+\+\s+(\d+))?     -> Optionally captures the slide offset as it might not always be present (`+ <numbers>`)
        */
        let pattern = #"^\s*(\d+)\s+([^\s]+(?:\s+[^\s]+)*)\s+(0x[0-9A-Fa-f]+)\s+(\S.+?)(?:\s+\+\s+(\d+))?$"#
        return frame.range(of: pattern, options: .regularExpression) != nil
    }
}
