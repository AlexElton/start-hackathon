# Polaris student case: map-first news app

See [PLAN.md](PLAN.md) for the product and the full technical plan.

## Getting started

```sh
make open        # opens Hackathon.xcworkspace (app + backend + SharedModels)
make backend     # runs the Vapor backend on http://localhost:8080
```

In Xcode, choose the **hackaton** scheme and an iPhone simulator to run the app, or the **App** scheme (My Mac) to run the backend.
The app alone can also be opened with `ios/hackaton.xcodeproj`.

Run the backend tests with `make test`.

**Everything runs on the phone.** The content engine (Polaris article decoder, repository, `FeedQuery`) and the mock
data live in the `FeedEngine` library in `SharedModels/`. The app runs it in-process through `LocalFeedService`, so a
phone needs no server; only the photos load from Polaris' image server. The Vapor backend wraps the same engine and
serves identical results over HTTP; `LiveFeedService` can talk to it if we deploy it later.

## API (`/api/v1`)

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/health` | `ok` |
| GET | `/feed` | `FeedPage`. Query params below, all optional |
| GET | `/articles/:id` | `ArticleDetail`, `404` if unknown |
| GET | `/categories` | `[Category]` |
| GET | `/papers` | `[Paper]` |

`/feed` params: `kinds` (`article,event,ad`), `categories`, `exclude`, `mute` (words in title/tags),
`bbox` (`minLat,minLon,maxLat,maxLon`), `near` (`lat,lon`) + `radiusKm`, `paper`, `when` (`tonight|today|week`),
`sort` (`time|distance|relevance`; `distance` needs `near`), `prefer` (categories for relevance), `limit` (default 200, max 500).
The app builds these with `FeedFilter.queryItems` from `SharedModels`. Bad values give `400` with a reason.

```sh
curl "localhost:8080/api/v1/feed?when=tonight"
curl "localhost:8080/api/v1/feed?near=63.4183,10.4045&radiusKm=2&sort=distance"
curl "localhost:8080/api/v1/articles/16grxK"
```

## Mock data (`SharedModels/Sources/FeedEngine/Data`)

| File | What |
| --- | --- |
| `articles/<id>.json` | Polaris articles exactly as exported. `PolarisArticle` decodes them |
| `article-meta.json` | Per article: category, paper, 3-bullet summary and one or more `locations`. Each location becomes a pin |
| `events.json` | Events with relative dates: `dayOffset` (0 = today) + `startTime`/`endTime` as `HH:mm`, Oslo time |
| `ads.json` | Student deals, valid from today for `daysValid` days |
| `categories.json`, `papers.json` | Lookup data. Every `categoryId`/`paperId` above must exist here |

To add an article: drop the Polaris JSON in `articles/` and add an entry to `article-meta.json`.
The server validates all references at startup and names the file and id if something is wrong.

## Repo layout

```text
Hackathon.xcworkspace     Open this in Xcode
ios/
├─ hackaton.xcodeproj     iOS 26 SwiftUI app (folders are synced: new files show up automatically)
└─ hackaton/
   ├─ App/                App entry, AppEnvironment (DI), RootView, MainTabView, AppConfig
   ├─ Features/           One folder per feature: Map, List, Settings
   │                      (add Onboarding, Sheet, Explain the same way)
   ├─ Core/
   │  ├─ Networking/      APIClient, the only type that talks to the backend
   │  └─ Stores/          SettingsStore (UserDefaults), later ReadStore
   ├─ DesignSystem/       Colours and shared UI pieces
   └─ Resources/          Assets.xcassets
backend/                  Vapor 4 server: thin HTTP wrapper around FeedEngine
├─ Sources/App/
│  ├─ configure.swift     Loads the bundled data, registers routes
│  ├─ routes.swift        The /api/v1 group
│  └─ Controllers/        Thin route handlers
SharedModels/             Swift package used by the app and the backend
├─ Sources/SharedModels/  Codable API types (FeedItem, ArticleDetail, FeedFilter, …)
└─ Sources/FeedEngine/    PolarisArticle, ContentRepository, FeedQuery + Data/ (the mock JSON)
```

## Conventions

- MVVM: views render, `@Observable` view models own state, models are `Sendable` structs.
- No singletons: dependencies live in `AppEnvironment` and are passed down with `.environment(...)`.
- New API types go in `SharedModels`, so the app and backend can't drift apart.
- Secrets live in `backend/.env` (see `.env.example`) and never in the app.
