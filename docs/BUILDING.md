# Building Forge

Forge builds on macOS with Xcode. If you do not have a Mac, you can still get a build by
forking the repository and using its CI.

## On a Mac

The Xcode project is generated with XcodeGen from `project.yml`; the `.xcodeproj` is not
checked in. You need a recent Xcode and iOS 16 or later.

1. Install XcodeGen (for example, `brew install xcodegen`).
2. Run `xcodegen generate` in the repository root to create `Forge.xcodeproj`.
3. Open the project, select the `Forge` target, and set a unique bundle identifier under
   Signing & Capabilities.
4. Select your development team, then build the `Forge` scheme.

## In the cloud, without a Mac

Fork the repository. The GitHub Actions workflow builds the app on a macOS runner on every
push and uploads the result, including an unsigned `.ipa`, as a build artifact.

1. Fork the repository on GitHub.
2. Push a commit, or run the CI workflow from the Actions tab.
3. Open the finished run and download the `.ipa` from its artifacts.
4. Sign the `.ipa` with your own Apple ID to install it. See the Installing section in the
   [README](../README.md).
