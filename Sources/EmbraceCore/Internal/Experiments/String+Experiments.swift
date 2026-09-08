//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

extension String {

    /// Removes exactly the six ASCII whitespace code points `U+0009`–`U+000D` and `U+0020` from both
    /// ends of the string, and nothing else.
    ///
    /// This deliberately does not use `CharacterSet.whitespacesAndNewlines`, which would also remove
    /// `U+0085`, `U+00A0`, `U+2028`, `U+2029` and `U+3000`. Those code points are meaningful parts of
    /// an identifier and must survive trimming, so that the value stored, the value measured against
    /// the length limits and the value matched when untracking are all the same.
    func strippedForExperiments() -> String {
        let scalars = unicodeScalars

        var start = scalars.startIndex
        while start < scalars.endIndex, Self.isExperimentWhitespace(scalars[start]) {
            start = scalars.index(after: start)
        }

        var end = scalars.endIndex
        while end > start {
            let previous = scalars.index(before: end)
            guard Self.isExperimentWhitespace(scalars[previous]) else {
                break
            }
            end = previous
        }

        return String(String.UnicodeScalarView(scalars[start..<end]))
    }

    private static func isExperimentWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        return (scalar.value >= 0x09 && scalar.value <= 0x0D) || scalar.value == 0x20
    }
}
