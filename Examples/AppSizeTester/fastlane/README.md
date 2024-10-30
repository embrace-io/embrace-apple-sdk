fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### calculate_sdk_size

```sh
[bundle exec] fastlane calculate_sdk_size
```

Calculates the size of the SDK by creating an .ipa with & without the SDK

and analyzes the difference between sizes of those .ipas, using the generate

'App Thinning Size Report.txt' file

### create_ipa

```sh
[bundle exec] fastlane create_ipa
```

Creates an .ipa for a specific scheme

Options:

 - scheme: the scheme to build. Should be one of the ones listed with `xcodebuild -list`. Mandatory.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
