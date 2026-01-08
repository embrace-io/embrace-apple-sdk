# Contributing

Thank you for participating in this project!

This document provides some basic guidelines for contributing to this repository. To propose improvements, feel free to submit a pull request or open an issue.

## Requirements

Before code can be accepted all contributors must read the [**code of conduct**](https://github.com/embrace-io/embrace-apple-sdk/blob/main/CODE_OF_CONDUCT.md) and complete our [**Individual Contributor License Agreement (CLA).**](https://forms.gle/SjXadmUcVwh6NrU68)

Our code of conduct applies to all platforms and venues related to this project; please follow it in all your interactions with the project and its participants.

## **Have a feature request or idea?**

Many great ideas for new features come from the community, and we'd be happy to consider yours! 

To share your idea or request, [open a GitHub Issue](https://github.com/embrace-io/embrace-apple-sdk/issues) using the dedicated issue template.

## **Found a bug?**

For urgent matters (such as outages) or issues concerning the Embrace service or UI, please email [support@embrace.io](mailto:support@embrace.io) or reach out in our [Community Slack](https://join.slack.com/t/embraceio-community/shared_invite/zt-ywr4jhzp-DLROX0ndN9a0soHMf6Ksow) for direct, faster assistance.

You may submit a bug report concerning the Embrace iOS SDK by [opening a GitHub Issue](https://github.com/embrace-io/embrace-apple-sdk/issues). Use the appropriate template and provide all the listed details to help us resolve the issue.

## **Have a patch?**

We welcome all code contributions to the library. If you have a patch adding value to the SDK, let us know! 

If you would like to contribute code you can do so through GitHub by forking the repository and sending a pull request. 

Please also format and lint by using:

```
$ make all
```

At a minimum, to be accepted and merged, Pull Requests must:

- Have a stated goal and a detailed description of the changes made.
- Include thorough test coverage and documentation, where applicable.
- Pass all tests and code quality checks on CI.
- Receive at least one approval from a project member with push permissions.

Make sure that your code is readable, well-encapsulated, and follows existing code and naming conventions. Any suppression of lint violations must be done in code and properly explained. The PR should comprise commits that are reasonably small with proper commit messages.

## Questions?

You can reach us at [support@embrace.io](mailto:support@embrace.io) or in our [Community Slack](https://join.slack.com/t/embraceio-community/shared_invite/zt-ywr4jhzp-DLROX0ndN9a0soHMf6Ksow).


## Building and Running Tests

Open the project in Xcode by either selecting the directory or the `Package.swift` file itself. If opening for the first time, Xcode may take a bit to resolve the Package Dependencies and index the project.

To build the project, select the `EmbraceIO-Package` scheme and in the menu select `Product -> Build (⌘+B)`.

### Testing

To run tests in Xcode, select the `EmbraceIO-Package` scheme and in the menu select `Product -> Test (⌘+U)`. You can also open the `Test Navigator (⌘+6)` and run individual tests using Xcode's UI.

There is also the `bin/test` command that can be used to run tests from the command line. It is recommended to pipe this through `xcpretty`.

```sh
bin/test | xcbeautify
```

## Linting, Formatting and Guidelines

To ensure consistent formatting across the codebase, we use both [swift-format](https://github.com/apple/swift-format) and [clang-format](https://clang.llvm.org/docs/ClangFormat.html), as well as [swiftlint](https://github.com/realm/SwiftLint) for linting.

The easiest way to run both formatters and linters is via:

```sh
make all
```

This will automatically apply formatting and linting to all Swift and C/Obj-C files using project-defined configurations (e.g., `.swift-format`, `.clang-format`, `.swiftlint.yml`).

To install the tools via Homebrew:

```sh
brew install swift-format
brew install clang-format
brew install swiftlint
```

You can also run individual format and lint targets:

```sh
make format 
make check-format 
make swift-format 
make check-swift-format
make lint
make check-lint
```

Make sure your code is formatted before submitting a pull request.

### Using SwiftLint

The SwiftLint Xcode plugin can be optionally enabled during development by using an environmental variable when opening the project from the commandline. 
```
EMBRACE_ENABLE_SWIFTLINT=1 open Package.swift
```
Note: Xcode must be completely closed before running the above command, close Xcode using `⌘Q` or running `killall xcode` in the commandline. 

Aside from the warnings and errors that will appear directly in Xcode, you can use SwiftLint to automatically correct some issues.
For this first you'll need to install SwiftLint in your local environment. Follow [SwiftLint's GitHub page](https://github.com/realm/SwiftLint) to see all available options.

* Use `make check-lint` to get a report on all the issues.
* Use `make lint` to fix issues automatically when possible.

### Setup pre-commit hook

We strongly recommend to use a pre-commit hook to make sure all the modified files follow the guidelines before pushing.
We have provided an example pre-commit hook in `.githooks/pre-commit`. Note that depending on your local environment, you might need to edit the pre-commit file to set the path to `swiftlint`.

```sh
cp .githooks/pre-commit .git/hooks/pre-commit
```

**Alternatives on how to setup the hook:**
* Use the `core.hooksPath` setting to change the hooks path (`git config core.hooksPath .githooks`)
