fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

Sync App Store signing certificates and provisioning profiles

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Submit to App Store

----


## Android

### android beta

```sh
[bundle exec] fastlane android beta
```

Upload AAB to Google Play internal testing

### android release

```sh
[bundle exec] fastlane android release
```

Promote to Google Play production

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
