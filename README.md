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

## Firebase connection

By default the app connects to Range `development` firebase account.

To switch to Firebase emulator use the `Range firebase emulator` scheme instead of `Range` to start the app.


## CI/CD

The builds are running on [Xcode Cloud](https://appstoreconnect.apple.com/teams/92067bb5-d614-4ce2-9dc8-dc6f07912892/apps/1643881765/ci/groups) and are configured to build a dev configuration (run tests and push to TestFlight).



## Mapbox

### 🔴*IMPORTANT*

The dependency to mapbox is set to "up to next minor version 10.5.0" which means it won't allow to upgrade past 10.5.x.

The reason is we observed a substantially bigger lag of pins when panning the pdf in 10.6.1 comparing to 10.5.1. (the experience is that pins our out of sync from PDF and they're behind. It was also observed previously, but the change to 10.6.1 is not acceptable)

🔴**ACHTUNG:** Before updating Mapbox to any version newer than 10.5.1 compare visually the sync between Mapbox and PDF.


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
