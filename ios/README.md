# Fitness iOS

SwiftUI iPhone client for the personal fitness app.

The app includes Workouts and Exercises tabs backed by the Rails API. Workout template management is online-only for now; offline workout execution and sync come later.

## Build

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```
