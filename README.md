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

## Mapbox

### Fonts

The style used for canvas annotations is using local fonts. This is achieved by providing a glyphs path in the style pointing to the `fonts` app path.

Currently there's one font added to the app - `SF Pro Text Semibold`.

### Converting fonts for Mapbox

In order to add more fonts they need to be converted from `ttf`/`otf` to `pbf` format.

To do this 

1. install [node-fontnik](https://github.com/mapbox/node-fontnik)
2. use its `/bin/build-glyphs` providing the `ttf`/`otf` as an input
3. drag the new font directory to the `fonts` in Xcode project (make sure that the newly added directory is a "blue" folder)
4. from now on the font can be referenced in Mapbox layers (using the name of the font directory)
