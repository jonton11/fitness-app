# Fitness iOS

SwiftUI iPhone client for the personal fitness app.

The app includes workout templates, local-first workout execution, workout
history, and exercise management. Enter the private server URL and issued bearer
token on first launch; the token is stored in Keychain and can be changed later
from Settings.

## Build

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```
