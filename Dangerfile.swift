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

    let sourceChanges = editedFiles.first(where: { $0.hasPrefix("Sources") })
    let testChanges = editedFiles.first(where: { $0.hasPrefix("Tests") })

    // check tests only if there were changes in the code
    if sourceChanges != nil && testChanges == nil {
        warn("No tests added / modified.")
    }

    // Run `make check-format check-swift-format` here
}

main()
