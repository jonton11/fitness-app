# Fitness iOS

SwiftUI iPhone client for the personal fitness app.

The app includes an Exercises tab for managing the shared exercise library through the Rails API.

## Build

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```
