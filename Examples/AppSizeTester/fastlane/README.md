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

Calculates the SDK size by generating two .ipa files (with and without the SDK)

and comparing their sizes using the 'App Thinning Size Report.txt' file.

Options:

 - skip_tuist_clean_cache: true to skip 'tuist clean dependencies' (default: false)

 - skip_lane_cleanup: true to skip cleanup of generated IPAs and project files (default: false)

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
