fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### release_homebrew

```sh
[bundle exec] fastlane release_homebrew
```

Build, notarize, publish, and update the Homebrew Cask

### build_macos

```sh
[bundle exec] fastlane build_macos
```

Create a signed macOS Release archive and App Store package

### upload_testflight

```sh
[bundle exec] fastlane upload_testflight
```

Build and upload the macOS package to App Store Connect TestFlight

### upload_screenshots

```sh
[bundle exec] fastlane upload_screenshots
```

Upload only App Store screenshots

### upload_metadata

```sh
[bundle exec] fastlane upload_metadata
```

Upload only App Store metadata

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
