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


## CI/CD

The builds are running on [Bitrise](https://app.bitrise.io/app/09db566fe608fa7b#/builds)

They can be either triggered manually on Bitrise or scheduled using Gitlab pipelines.

We have 2 workflows defined on Bitrise:

1. `test` 
  - running `swiftformat` linter, building the project and running the tests
  - triggered from Gitlab on each push to `develop` branch
2. `deploy-to-firebse`
  - updates the build number (not commited to the repo, just sync with current bitrise build number)
  - builds the app for ad-hoc distribution
  - uploads to Firebase distribution
  - triggered from Gitlab on each push to `master` branch

  
### CI/CD configuration

#### Bitrise access to Gitlab

- a token added by Bitrise in [`Gitlab iOS project repository settings`](https://gitlab.com/range.io/ios/-/settings/repository)/`Deploy keys`
- configured in [`Bitrise iOS app settings`](https://app.bitrise.io/app/09db566fe608fa7b#/settings)/`SSH Settings`

#### Trigger Bitrise from Gitlab

This is done via [gitrise script](https://github.com/azohra/gitrise.sh) (see [article](https://medium.com/tumiya/building-ci-cd-pipelines-for-ios-projects-using-gitlab-and-bitrise-b4f895e0375e) for more details)

- the script is commited in the iOS repo
- The script is configured to run in the Gitlab pipeline using `.gitlab-ci.yml`
- the script required some Bitrise keys, etc., configured in [`Gitlab iOS project CI/CD settings`](https://gitlab.com/range.io/ios/-/settings/ci_cd)/`Variables`

The script required a `jq` tool, so a custom container was added to Gitlab iOS project
  
  - [container source](https://gitlab.com/gitlab-ci-utils/curl-jq)
  - to build and add it to Gitlab:
    - clone the source on your local machine
    - `docker login registry.gitlab.com`
    - `docker build -t registry.gitlab.com/range.io/ios/curl-jq .`
    - `docker push registry.gitlab.com/range.io/ios/curl-jq`

#### Allow Bitrise to sign Range iOS apps

- A key for Bitrise was added in the [`App Store Connect API keys`](https://appstoreconnect.apple.com/access/api)
- The key is configured in Bitrise in [`User profile/Apple Service Connection`](https://app.bitrise.io/me/profile#/apple_developer_account)
- Then it's selected for Bitrise project in [`Project/Team`](https://app.bitrise.io/app/09db566fe608fa7b#/team)/`Apple Service Connection`

- Development and distribution code signing certificates were manually created on [`Range developer account`](https://developer.apple.com/account/resources/certificates/list) and added to [`Bitrise codesigning configuration`](https://app.bitrise.io/app/09db566fe608fa7b/workflow_editor#!/code_signing)


#### Allow Bitrise to push apps to Firebase distribution

- Firebase app id and token are stored in [`Bitrise app workflow secrets`](https://app.bitrise.io/app/09db566fe608fa7b/workflow_editor#!/secrets)
- For instructions to obtain the token see [`Bitrise iOS recipes`](https://devcenter.bitrise.io/en/steps-and-workflows/workflow-recipes-for-ios-apps/-ios--deploy-to-firebase-app-distribution.html#ot-lst-cnt)





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
