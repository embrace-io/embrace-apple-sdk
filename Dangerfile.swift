import Danger

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

    let changelogChanged = editedFiles.contains("CHANGELOG.md")
    let sourceChanges = editedFiles.first(where: { $0.hasPrefix("Sources") })
    let testChanges = editedFiles.first(where: { $0.hasPrefix("Tests") })

    // for release candidates, there must be a changelog update
    if danger.github.pullRequest.head.label.contains("release/") && !changelogChanged {
        fail("Releases must have CHANGELOG updates.")

    // otherwise only throw a warning if there was code changes without a changelog update
    } else if !changelogChanged && sourceChanges != nil {
        warn("No CHANGELOG entry added.")
    }
    
    // check tests only if there were changes in the code
    if sourceChanges != nil && testChanges == nil {
        warn("No tests added / modified.")
    }

    // lint modified files
    SwiftLint.lint(.files(editedFiles), inline: true, quiet: false)
}

main()
