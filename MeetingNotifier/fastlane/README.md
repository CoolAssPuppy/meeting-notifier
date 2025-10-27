fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac prep

```sh
[bundle exec] fastlane mac prep
```

Verify environment and prerequisites

### mac test

```sh
[bundle exec] fastlane mac test
```

Run all tests

### mac bump_patch

```sh
[bundle exec] fastlane mac bump_patch
```

Increment patch version (1.0.0 -> 1.0.1)

### mac bump_minor

```sh
[bundle exec] fastlane mac bump_minor
```

Increment minor version (1.0.0 -> 1.1.0)

### mac bump_major

```sh
[bundle exec] fastlane mac bump_major
```

Increment major version (1.0.0 -> 2.0.0)

### mac build

```sh
[bundle exec] fastlane mac build
```

Build the app

### mac beta

```sh
[bundle exec] fastlane mac beta
```

Deploy to TestFlight

### mac release

```sh
[bundle exec] fastlane mac release
```

Deploy to App Store

### mac download_metadata

```sh
[bundle exec] fastlane mac download_metadata
```

Download App Store metadata

### mac upload_metadata

```sh
[bundle exec] fastlane mac upload_metadata
```

Upload App Store metadata

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
