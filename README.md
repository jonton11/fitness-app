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
Exercise management endpoints are available under `http://localhost:3000/api/v1/exercises`.

The web app serves `http://localhost:5173`, proxies `/api` requests to Rails, and opens on the exercise library.

## Exercise Library

Exercises can be created, searched, edited, archived, and restored. Archived exercises are hidden from the default active list, but remain available through archive filters for historical workout records.

The same Rails API backs the React web client and the SwiftUI Exercises tab.

## API

With Docker:

```sh
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgres://fitness:fitness@postgres:5432/fitness_test api bash -lc "./bin/rails db:prepare && ./bin/rails test"
docker compose run --rm --no-deps api ./bin/rubocop
docker compose run --rm --no-deps api ./bin/brakeman --no-pager
```

Without Docker:

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

With Docker:

```sh
docker compose run --rm --no-deps web npm run lint
docker compose run --rm --no-deps web npm run format
docker compose run --rm --no-deps web npm run test
docker compose run --rm --no-deps web npm run build
```

Without Docker:

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
