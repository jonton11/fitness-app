# fitness-app

Personal fitness and health application tracker.

## Apps

- `api/`: Rails API backed by PostgreSQL
- `web/`: React, TypeScript, and Vite web client
- `ios/`: SwiftUI iPhone client

## Local Development

Run the containerized development stack:

```sh
docker compose up --build
```

The Rails API serves `http://localhost:3000/api/v1/health`.

The web app serves `http://localhost:5173` and proxies `/api` requests to Rails.

## API

```sh
cd api
asdf exec bundle install
asdf exec bundle exec rails db:prepare
asdf exec bundle exec rails test
env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache asdf exec bundle exec rubocop
asdf exec bundle exec brakeman --no-pager
```

## Web

Use Node 24.

```sh
cd web
npm ci
npm run lint
npm run format
npm run test
npm run build
```

## iOS

```sh
cd ios
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing
```
