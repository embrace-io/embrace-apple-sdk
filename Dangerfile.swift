// fileImport: DangerfileExtensions/TimedWaitCheck.swift
import Danger
import Foundation

let danger = Danger()

func main() {
    guard danger.github != nil else {
        print("Github not found")
        return
    }

    // require a description of the changes
    let body = danger.github.pullRequest.body?.count ?? 0
    if body < 1 {
        warn("Please provide a description for the changes in this Pull Request.")
    }

    let editedFiles = danger.git.modifiedFiles + danger.git.createdFiles

    let sourceChanges = editedFiles.first(where: { $0.hasPrefix("Sources") })
    let testChanges = editedFiles.first(where: { $0.hasPrefix("Tests") })

    // check tests only if there were changes in the code
    if sourceChanges != nil && testChanges == nil {
        warn("No tests added / modified.")
    }

    if testChanges != nil {
        checkTimedWaits()
    }

    // Run `make check-format check-swift-format` here
}

/// Warns inline on timed waits that the pull request adds under `Tests/`.
func checkTimedWaits() {
    // A `pull_request` run checks out the merge commit, so its first parent is the tip of the base
    // branch and this diff is exactly the pull request's change. The checkout needs `fetch-depth: 2`.
    let diffCommand = "git diff --unified=0 --no-color --no-ext-diff HEAD^1 HEAD -- Tests"

    // The Danger action runs as root in a container, over a workspace owned by the runner user, and
    // its git (2.25) rejects that as dubious ownership. That git only reads `safe.directory` from
    // global or system config, so on CI add the workspace to the container's global config. `HOME`
    // there is a per-job directory. Locally the repository is the user's own, so nothing is added.
    let trustWorkspace = "if [ \"$GITHUB_ACTIONS\" = true ]; then git config --global --add safe.directory \"$PWD\"; fi"

    let diff: String
    do {
        // `spawn` runs the command through `/bin/sh -c`.
        diff = try danger.utils.spawn("\(trustWorkspace) && \(diffCommand)")
    } catch {
        warn("Couldn't diff the tests against the base branch to check for timed waits: \(error)")
        return
    }

    let findings = TimedWaitCheck.findings(inDiff: diff) { path in
        try? String(contentsOfFile: path, encoding: .utf8)
    }
    for finding in findings {
        warn(message: finding.message, file: finding.file, line: finding.line)
    }
}

main()
