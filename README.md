## Code formatting

The project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) for formatting the code.

In current setup the code is not being formatted automatically.

- Xcode editor extension can be added as described [here](https://github.com/nicklockwood/SwiftFormat#xcode-source-editor-extension)

- recommended usage is to run `swiftformat .` from the project directory. There's a `.swiftformat` configuration file provided in the project dir and it'll be used automatically

- it is highly recommended to configure a local pre-commit hook to abort commit if SwiftFormat lint fails. Follow the instructions [here](https://github.com/nicklockwood/SwiftFormat#git-pre-commit-hook) and add the following content to `.git/hooks/pre-commit`:

```
#!/bin/bash
git-format-staged --no-write -f 'swiftformat --lint "{}" >&2' '*.swift'
```


## Running locally

The project depends on the Mapbox iOS SDK which is not available publicly.
In order for Swift Package Manager to download it, follow the instructions in “Configure your secret token” in the [Mapbox installation guide](https://docs.mapbox.com/ios/maps/guides/install/).

**Note:** currently we don't have a Range Mapbox account, so in order to follow the instructions, one need to create a free mapbox account.
