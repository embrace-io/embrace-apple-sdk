# Embrace


## Documentation

[API Reference Docs](https://embrace-io.github.io/embrace-apple-core-internal/documentation/embrace_ios_core).

## Prerequisities

### Github

We are using our own KSCrash fork, so we need to set up Github credentials in Xcode to provide the required access.

* Go to the "Accounts" tab in "Settings" (`cmd+,`)
* Verify you have Github credentials saved, or click the `+` sign to add Github credentials.

## Building and Running Tests

Open the project in Xcode by either selecting the directory or the `Package.swift` file itself. If opening for the first time, Xcode may take a bit to resolve the Package Dependencies and index the project.

To build the project, select the `EmbraceIO-Package` scheme and in the menu select `Product -> Build (⌘+B)`.

### Testing

To run tests in Xcode, select the `EmbraceIO-Package` scheme and in the menu select `Product -> Test (⌘+U)`. You can also open the `Test Navigator (⌘+6)` and run individual tests using Xcode's UI.

There is also the `bin/test` command that can be used to run tests from the command line. It is recommended to pipe this through `xcpretty`.

```sh
bin/test | xcpretty
```

## Linting and Guidelines

All source files must follow our guidelines described [here](https://www.notion.so/embraceio/iOS-Developer-Guidelines-078360496fff4379b033e67c377d42e7).

We use [SwiftLint](https://github.com/realm/SwiftLint) to enforce them and every pull request must satisfy them to be merged.
SwiftLint is used as a plugin in all of our targets to get warnings and errors directly in Xcode.

### Using SwiftLint

Aside from the warnings and errors that will appear directly in Xcode, you can use SwiftLint to automatically correct some issues.
For this first you'll need to install SwiftLint in your local environment. Follow [SwiftLint's GitHub page](https://github.com/realm/SwiftLint) to see all available options.

* Use `swiftlint lint --strict` to get a report on all the issues.
* Use `swiftlint --fix` to fix issues automatically when possible.

### Setup pre-commit hook

We strongly recommend to use a pre-commit hook to make sure all the modified files follow the guidelines before pushing.
We have provided an example pre-commit hook in `.gitooks/pre-commit`. Note that depending on your local environment, you might need to edit the pre-commit file to set the path to `swiftlint`.

**Alternatives on how to setup the hook:**
* Simply copy `.githooks/pre-commit` into `.git/hooks/pre-commit`.
* Use the `core.hooksPath` setting to change the hooks path (`git config core.hooksPath .githooks`)


## Troubleshooting

### Github auth issues

If you cannot fetch the `KSCrash` dependency, you most likely have Github auth issues.

1. Verify you have set up Github credentials in on the "Accounts" tab in "Settings"
2. Enter the passcode for your SSH key on that page if prompted to do so.
3. If you have the following in your `.gitconfig`, remove it since Xcode apparently does not handle this

```
[url "ssh://git@github.com/"]
  insteadOf = https://github.com/
```

To test if your auth changes fixed things, attempt to fetch the dependencies with "File" -> "Packages" --> "Reset package caches"
