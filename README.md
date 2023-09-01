# Embrace


## Documentation

[API Reference Docs](https://embrace-io.github.io/embrace-apple-core-internal/documentation/embrace_ios_core).

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
