//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public struct EmbraceStackTrace: Equatable {
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
    /// - Throws: An `EmbraceStackTraceError.invalidFormat` if any of the frames are not in the expected format.
    public init(frames: [String]) throws {
        guard frames.allSatisfy(EmbraceStackTrace.isValidStackFrame) else {
            throw EmbraceStackTraceError.invalidFormat
        }
        self.frames = frames
    }

    /// Validates if a given frame string follows the required format.
    /// - Parameter frame: a stack trace frame.
    /// - Returns: whether the format is valid or invalid.
    private static func isValidStackFrame(_ frame: String) -> Bool {
        /*
         Regular expression pattern breakdown:

         ^\s*                 → Allows optional leading spaces at the beginning
         (\d+)                → Captures the frame index (a sequence of digits)
         \s+                  → One or more whitespaces
         (.*?)                → Captures the module name (non-greedy/lazy to allow spaces)
         \s+                  → One or more whitespaces
         (0x[0-9A-Fa-f]+)     → Captures the memory address hex (must start with `0x`)
         \s+                  → One or more whitespaces
         (.+?)                → Captures the function/method symbol (non-greedy/lazy)
         (?:\s+\+\s+(\d+))?   → Optionally captures the slide offset as it might not always be present (`+ <numbers>`)
        */
        let pattern = #"^\s*(\d+)\s+(.*?)\s+(0x[0-9A-Fa-f]+)\s+(.+?)(?:\s+\+\s+(\d+))?$"#

        return frame.range(of: pattern, options: .regularExpression) != nil
    }
}

