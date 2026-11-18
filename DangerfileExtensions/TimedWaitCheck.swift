import Foundation

/// A timed wait on a line that a pull request adds under `Tests/`.
struct TimedWaitFinding: Equatable {
    let file: String
    let line: Int
    let message: String
}

/// Flags timed waits on the lines a pull request adds to Swift files under `Tests/`.
///
/// A test that waits on SDK work should synchronize on the queue that does it (`queue.sync {}`,
/// `waitForAllWork()`, `storage.waitForPendingCoreDataOperations()`) and assert afterwards. The
/// patterns below are the ones that failed on CI or passed whatever the code did.
///
/// A line is skipped when it, or the line above it, has a `timed-wait:` comment saying why the wait
/// is needed, for example a real `URLSession` round trip or a deadlock guard.
enum TimedWaitCheck {
    static let suppressionMarker = "timed-wait:"

    /// Files that define the wait helpers rather than call them.
    static let excludedFiles: Set<String> = ["Tests/TestSupport/XCTestCase+WaitHelpers.swift"]

    private struct Rule {
        let pattern: NSRegularExpression
        let message: String
        /// When set, the rule matches only if the whole call, which may span several lines, has no
        /// `timeout:` argument.
        let matchesOnlyWithoutTimeout: Bool

        init(_ pattern: String, matchesOnlyWithoutTimeout: Bool = false, message: String) {
            self.pattern = try! NSRegularExpression(pattern: pattern)
            self.message = message
            self.matchesOnlyWithoutTimeout = matchesOnlyWithoutTimeout
        }
    }

    private static let drainAdvice =
        "Drain the queue that does the work (`queue.sync {}`, `waitForAllWork()`, `storage.waitForPendingCoreDataOperations()`) and assert after it."

    private static let rules: [Rule] = [
        Rule(
            #"\b(?:Thread\.sleep|usleep|sleep)\s*\(|\bwait\(\s*delay:"#,
            message: "Fixed sleep in a test. It is too short on a loaded runner and too long everywhere else. \(drainAdvice)"
        ),
        Rule(
            #"\.asyncAfter\s*\("#,
            message: "`asyncAfter` in a test either checks a condition once at a fixed time, which no timeout can save, or stands in for a sleep. "
                + "\(drainAdvice) If the work runs where the test can't reach it, poll with `wait(until:)`."
        ),
        Rule(
            #"\b(?:wait\(\s*for:|fulfillment\(\s*of:)"#,
            matchesOnlyWithoutTimeout: true,
            message: "Wait without a `timeout:`. XCTest then waits until the test's execution allowance, so a lost callback hangs the run instead of failing the test. "
                + "Pass a timeout; for a positive wait a large one costs nothing."
        ),
        Rule(
            #"until:\s*\{\s*!"#,
            message: "Negative poll. `wait(until:)` returns as soon as its condition holds, so a flag that starts false passes at once whatever the code does. "
                + "Drain the queue that does the work and assert, or use an inverted expectation fulfilled by the event."
        ),
        // `timeout: 0` is not flagged: it asserts that the expectation is already fulfilled.
        Rule(
            #"timeout:\s*(?:\.veryShortTimeout|\.shortTimeout|0?\.(?=\d*[1-9])\d+|[12](?:\.\d+)?)(?![\w.])"#,
            message: "Timeout below `.defaultTimeout` (3 s). A positive wait returns as soon as its condition holds, so a larger budget costs nothing, "
                + "and a short one flakes under sanitizers. If this is a window for something that must not happen, use an inverted expectation."
        )
    ]

    /// Returns the timed waits on added lines in `diff`, a unified diff with any amount of context.
    ///
    /// - Parameters:
    ///   - diff: Output of `git diff` for the files to check.
    ///   - fileContents: The new contents of a file by its repository-relative path. Used to read
    ///     multi-line calls and the line above an added line. Returns `nil` if the file can't be
    ///     read.
    static func findings(inDiff diff: String, fileContents: (String) -> String?) -> [TimedWaitFinding] {
        var findings: [TimedWaitFinding] = []
        var currentFile: String?
        var fileLines: [String] = []
        var nextNewLine = 0

        for rawLine in diff.components(separatedBy: "\n") {
            if rawLine.hasPrefix("+++ ") {
                let path = String(rawLine.dropFirst(4))
                if path.hasPrefix("b/"), shouldCheck(String(path.dropFirst(2))) {
                    currentFile = String(path.dropFirst(2))
                    fileLines = fileContents(currentFile!)?.components(separatedBy: "\n") ?? []
                } else {
                    currentFile = nil
                }
                continue
            }
            if rawLine.hasPrefix("@@ ") {
                nextNewLine = newLineStart(ofHunkHeader: rawLine) ?? 0
                continue
            }
            guard let file = currentFile else { continue }

            if rawLine.hasPrefix("+") {
                let text = String(rawLine.dropFirst())
                findings += check(line: text, number: nextNewLine, in: file, fileLines: fileLines)
                nextNewLine += 1
            } else if rawLine.hasPrefix(" ") {
                nextNewLine += 1
            }
        }
        return findings
    }

    private static func shouldCheck(_ path: String) -> Bool {
        path.hasPrefix("Tests/") && path.hasSuffix(".swift") && !excludedFiles.contains(path)
    }

    /// Parses the new-file start line from a hunk header such as `@@ -10,2 +12,3 @@`.
    private static func newLineStart(ofHunkHeader header: String) -> Int? {
        guard let plus = header.range(of: " +") else { return nil }
        let digits = header[plus.upperBound...].prefix { $0.isNumber }
        return Int(digits)
    }

    private static func check(line text: String, number: Int, in file: String, fileLines: [String]) -> [TimedWaitFinding] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") {
            return []
        }
        if text.contains(suppressionMarker) {
            return []
        }
        // Line numbers are 1-based; the line above is at index `number - 2`.
        if number >= 2, number - 2 < fileLines.count, fileLines[number - 2].contains(suppressionMarker) {
            return []
        }

        let code = stripTrailingComment(text)
        var findings: [TimedWaitFinding] = []
        for rule in rules where matches(rule.pattern, code) {
            if rule.matchesOnlyWithoutTimeout {
                let call = callText(startingAt: number, fileLines: fileLines, fallback: code)
                if call.contains("timeout:") { continue }
            }
            findings.append(TimedWaitFinding(file: file, line: number, message: rule.message))
        }
        return findings
    }

    private static func matches(_ pattern: NSRegularExpression, _ text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func stripTrailingComment(_ text: String) -> String {
        guard let range = text.range(of: "//") else { return text }
        return String(text[..<range.lowerBound])
    }

    /// The text of the call on line `number`, continued over the following lines until its
    /// parentheses balance, so a `timeout:` on a later line counts.
    private static func callText(startingAt number: Int, fileLines: [String], fallback: String) -> String {
        guard number >= 1, number - 1 < fileLines.count else { return fallback }
        var text = ""
        var depth = 0
        for line in fileLines[(number - 1)...].prefix(20) {
            let code = stripTrailingComment(line)
            text += code + "\n"
            depth += code.filter { $0 == "(" }.count - code.filter { $0 == ")" }.count
            if depth <= 0 { break }
        }
        return text
    }
}
