# Polaris student case – map-first news app

Oct 15, 2026 · @Iver

## 1. The task explained

Polaris Media wants a product for students, made by students, where local journalism plays a role. It must be shown as a working prototype at the end of a two-day case.

- **Who:** Polaris Media, headquartered in Trondheim, owns Adresseavisen, Fædrelandsvennen, Sunnmørsposten, iTromsø, Gøteborgs-Posten and 73 other local and regional titles in Norway and Sweden.
- **The ask:** solve a real need in student life. Not "the newspaper with a student tab". Repackaging articles is allowed, but we start from our needs, not the media group's.
- **Form:** anything: an app, a website, a service, a chatbot, a tool, a game or a calendar. The only requirement is that we would actually want it.
- **Material:** a set of Polaris articles in JSON that we can use freely.

The demo at the end of day 2 must cover five points:

| # | Demo point | What Polaris wants to see |
| --- | --- | --- |
| 1 | Behovet | The problem we solve |
| 2 | Produktet | What it is and how it works in practice |
| 3 | Fungerende prototype | Something they can click through. It may be unpolished, but it must run |
| 4 | Hva kan vi bidra med | What a local media house adds: content, journalists, data, closeness to the city |
| 5 | Retention | How the product reaches students, and why they come back |

**Our scope:** an iOS app (SwiftUI) that runs fully on the phone, plus a Swift backend (Vapor) that serves the same engine over HTTP. All articles, events, ads and categories are mocked JSON served by the backend. Gemini is used only for the "Forklar" explanations.

## 2. Problem and solution

News is sorted by when it was published, not by where it happens. We put local news, events and student deals on a 3D map you filter yourself, and explain anything you don't understand with one tap.

### What we think students want

- See **where** news happens, on a map.
- **Choose** what kind of news you see, and hide what you don't want.
- See **what's happening tonight** (hva skjer i kveld).
- Tap a word or a person and get it **explained**.
- Maybe: local **deals and discounts** (tilbud).

### 1. Behovet: the problem

- Students care about their campus, neighbourhood and city, but a news feed shows neither place nor distance.
- "Hva skjer i kveld?" has no single answer. News, events and student deals are spread across many apps and sites.
- Too much noise. There is no easy way to pick topics or mute the ones you don't care about.
- Local news assumes local knowledge. A new student doesn't know the local politician, the place or the term.

### 2. Produktet: how it works

1. **Onboarding:** pick categories, blacklist what you don't want, and tap your region on a map of Norway, which gives you its regional avis and the local papers under it. Or start at your own position.
2. **Wow intro:** the first time, a slow cinematic zoom from the globe down to your city. Later launches get a fast zoom from Europe, which can be turned off.
3. **Map view:** a 3D satellite map with a pin for every article, event and deal. Pins fan out into clusters with a count when you zoom out, and read items fade.
4. **Sheet:** tap a pin to open a short, scannable card in a 90% sheet. Tap a cluster to swipe through its items, with a "2 / 5" position label.
5. **Les hele saken:** opens the full article fullscreen, with a "Fra Adresseavisen" source badge.
6. **Forklar:** select any word, name or place, tap Forklar, and a short Gemini explanation streams into a tooltip.
7. **List view:** a classic news list filtered by Nær meg, I kveld, Relevant or Sted.
8. **Settings:** map style, intro on or off, categories and blacklist, local avis.

### 3. Prototype: what we demo

- A running SwiftUI app on an iPhone, backed by our deployed Vapor backend, with a laptop as fallback.
- Demo script, about 3 minutes: onboarding → globe-to-Trondheim zoom → zoom out to show clusters → tap a cluster and swipe → Les hele saken → select a name and tap Forklar → List view with "I kveld" → back to the map with read pins faded.

### 4. Hva Polaris kan bidra med

- **Content and data:** 70+ local titles together form a national news map. Tagging a location when an article is published is the cheapest big win.
- **Events and local partners:** event calendars and deals from local businesses feed the events and tilbud layers, and give the ads layer a revenue model.
- **Journalists:** short summaries, and verified explainers for recurring local names, places and terms.
- **Trust and brand:** every card shows its source paper and links to the full article, which drives traffic and subscriptions.
- **Distribution:** reach through the papers themselves, student subscriptions, fadderuke and linjeforeninger.

### 5. Retention

- **Reach:** launch during fadderuke, through linjeforeninger, and as part of a student subscription that the local paper promotes.
- **Daily habit:** "what's around me, and what's on tonight?" Events and deals change every day, so the map is never the same twice.
- **Progress:** read items fade, so clearing your area gives a small "inbox zero" feeling.
- **Personal from minute one:** your avis, your categories, your blacklist.
- **Later:** smart, interactive notifications (see section 5).

## 3. Implementation / systemutviklingsplan

We build a SwiftUI app (MVVM) against a small Vapor backend. The backend serves mocked JSON and proxies Gemini Flash for streamed explanations; nothing else uses AI.

### 3.1 Tech stack

| Layer | Choice | Why |
| --- | --- | --- |
| iOS app | SwiftUI, iOS 17+, `@Observable` MVVM, async/await | Modern, little boilerplate, easy to preview and test |
| Map | `MKMapView` in a `UIViewRepresentable`, 3D satellite with realistic elevation | SwiftUI `Map` has no native clustering or custom cluster views |
| Backend | Swift + Vapor 4, AsyncHTTPClient | Same language as the app. Vapor 4.95+ can stream response bodies, which SSE needs ([release notes](https://github.com/vapor/vapor/releases/tag/4.95.0)) |
| Data | One JSON file per content type, loaded into memory at startup | Read-only demo data, so no database |
| AI | Gemini Flash via `streamGenerateContent?alt=sse`, only for Forklar | Fast and cheap, and it streams text as it is generated ([Gemini models](https://ai.google.dev/gemini-api/docs/latest-model)) |
| Shared code | Local SPM package `SharedModels` with Codable DTOs | One source of truth for the API contract on both sides |
| On-device state | `UserDefaults` behind `SettingsStore` and `ReadStore` | Tiny data; SwiftData would be overkill |

### 3.2 Coding principles

- **MVVM, one job per type.** Views only render and forward user actions. ViewModels are `@MainActor @Observable final class` and own state and logic. Models are `struct`s that are `Codable`, `Identifiable`, `Hashable` and `Sendable`.
- **Protocol-oriented services.** `FeedServicing` and `ExplainServicing` each have a live and a mock implementation. The mocks power SwiftUI previews, unit tests and an offline demo fallback.
- **Dependency injection, no singletons.** An `AppEnvironment` holding services and stores is created once in the `App` and passed down with `.environment(...)`.
- **Make illegal states unrepresentable.** Use enums for `ItemKind`, `FeedItem.Details`, `LoadState<T>` (idle, loading, loaded, failed), `SheetContent` and `ExplainState`.
- **Structured concurrency.** async/await everywhere. Cancel the previous fetch `Task` when the map moves, and stream explanations with `AsyncThrowingStream`.
- **Feature folders.** `Features/{Onboarding, Map, Sheet, Explain, List, Settings}`, plus `Core/{Networking, Stores, Location}` and `DesignSystem/`.
- **Thin backend controllers.** Logic lives in `ContentRepository` and `FeedQuery`. The repository is a protocol, so the JSON can later be swapped for a database or a real Polaris API.
- **Secrets stay on the server.** The Gemini key is read from `GEMINI_API_KEY` and the model id from `GEMINI_MODEL` (for example `gemini-flash-latest`), so we can switch Flash versions without code changes.
- **Git.** Feature branches, small PRs, one reviewer, and `main` always runs.

### 3.3 Mock data: JSON files, no database

The engine reads five JSON files and one GeoJSON file from `SharedModels/Sources/FeedEngine/Data/` once at startup (on the phone, and in the backend), keeps them in memory, and filters per request. Nothing is stored on the server: the only per-user state, settings and read items, lives on the phone.

| File | Contents | Notes |
| --- | --- | --- |
| `articles.json` | Polaris articles in our schema: location, category, 3-bullet summary, paper, body paragraphs | Converted once before coding, by hand or with an LLM in chat; not at runtime |
| `events.json` | Concerts, quizzes, sports and student events | Store `dayOffset` + `"19:00"` instead of a fixed date, so "I kveld" always has events on demo day |
| `ads.json` | Local deals: merchant, offer, days valid, location | Place them near campuses so the tilbud layer looks alive |
| `categories.json` | id, Norwegian name, SF Symbol, colour | Used by onboarding, filters and pin colours |
| `papers.json` | Avis id, name, city, coordinate, logo, colour, `regionId`, `level` (regional or local) | The single source of which local avis belongs to which zone |
| `regions.geojson` | One feature per zone: fylke outline, id, name, colour, regional avis id, label point | Start from Kartverket's coast-clipped 2024 fylke data ([Geonorge](https://geonorge.no:/geonetworktest/srv/api/records/a9c64d66-f484-4a8f-a7b4-723fdaa578d3)) and simplify it with mapshaper to a few hundred KB, so the map stays smooth |

One file per kind is best. Each kind has its own schema, teammates can edit them in parallel, and the repository merges them into one `[FeedItem]` list when it loads.

### 3.4 Backend (Vapor)

> **Update:** everything must run on the phone. The repository, `FeedQuery`, the Polaris decoder and the JSON now live in the `FeedEngine` library (`SharedModels/Sources/FeedEngine`). The app runs it in-process via `LocalFeedService`; the Vapor app below wraps the same engine, so both always return identical results. Gemini "Forklar" will still need the network.


```text
Backend/
├─ Package.swift          // Vapor, AsyncHTTPClient, SharedModels
├─ (data now in SharedModels/Sources/FeedEngine/Data)
└─ Sources/App/
   ├─ configure.swift     // load JSON, set up GeminiClient, register routes
   ├─ routes.swift        // the /api/v1 group
   ├─ Controllers/        // Feed, Article, Meta, Explain
   └─ Services/           // ContentRepository, FeedQuery, GeminiClient
SharedModels/             // local SPM package used by app and backend
```

- **Feed filtering (`FeedQuery`):** parse the query params into a typed struct. Filter by kinds, categories, blacklisted categories and muted words. Then filter by area: a bounding box for the map, or `near` + radius for the list. Then by time: `when=tonight` means events starting today after 16:00. Finally sort by distance (haversine), time or relevance.
- **Relevance score:** +2 if the category is one the user prefers, +1 if it is within 5 km, newest first on ties. Simple enough to explain in the demo.
- **Explain:** validate the input (term 1–80 characters, context at most 2,000). Build a short Norwegian system instruction: explain in 2–3 sentences for a student, and say so if unsure. Call Gemini with `streamGenerateContent?alt=sse` through AsyncHTTPClient, and forward each text chunk to the app as SSE with `Response.Body(managedAsyncStream:)`. Set `Content-Type: text/event-stream` and `Cache-Control: no-cache`. No caching; every tap streams fresh.
- **Prompt safety:** the article text goes in as data in the user turn, and the system instruction says to only explain the term.
- **Deploy:** run it on a small host such as Railway, so the demo doesn't depend on a laptop on venue Wi-Fi. `swift run` on a laptop is plan B.

### 3.5 iOS app, feature by feature

**App shell**

- `RootView` shows `OnboardingFlow` until `settings.hasOnboarded` is true, then `MainTabView`.
- `MainTabView` is the bottom tab bar: Kart, Liste and Innstillinger, with room for more tabs later.

**Onboarding**

- Four steps, each with a **Neste** button: categories (a chip grid, multi-select) → blacklist (categories plus muted words) → **region map** → done.
- `OnboardingViewModel` edits a draft `AppSettings`, saves it to `SettingsStore` on finish, and asks the map for the globe intro.

**Region map (onboarding step 3)**

Instead of a list, you pick your avis by tapping a zone on a 2D map of Norway. There is one zone per fylke where Polaris has a regional avis. Tapping a zone selects that regional avis plus every local avis under it.

| Zone (fylke) | Regional avis | Local avis under it (examples) |
| --- | --- | --- |
| Trøndelag | Adresseavisen | Fosna-Folket, Hitra-Frøya, Innherred, Opdalingen, Sør-Trøndelag, Trønderbladet |
| Møre og Romsdal | Sunnmørsposten | Romsdals Budstikke, Driva, Møre-Nytt, Vikebladet Vestposten, Åndalsnes Avis |
| Troms | iTromsø | Harstad Tidende, Folkebladet |
| Agder | Fædrelandsvennen | Agderposten, Lindesnes, Lister, Vennesla Tidende |

The examples come from Polaris' [2020 editorial report](https://www.polarismedia.no/wp-content/uploads/2023/02/Polaris-Media-Redaksjonell-%C3%85rsrapport-2020.pdf); titles may have changed since, so check them against the paper names in the case's articles JSON.

- **Map:** a separate SwiftUI `Map`, since this screen needs no clustering. Use `.mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))` and `interactionModes: [.pan, .zoom]`, so it stays 2D with no rotate or pitch.
- **Rest of the world grayed out:** draw one gray `MapPolygon` over the whole area around Norway first, then the zones on top. Fylker without a Polaris avis get a light neutral fill and a thin border, so the outline of Norway still reads, and they can't be tapped.
- **Zones:** one `MapPolygon` per polygon part (fylker have islands, so a zone is a multipolygon). Fill with the avis colour at about 50% opacity, and stroke with the same hue about 25% darker at 1.5 pt.
- **Label:** an `Annotation` with the avis logo and name, centred on a hand-picked `labelPoint` per zone. The geometric centre of a Norwegian fylke often lands in the sea or at an edge.
- **Hover and selection:** iPad and Mac pointers get a hover highlight through `.onContinuousHover`: a lighter fill and a thicker border. On iPhone the feedback comes on tap. The selected zone animates to about 80% fill with a 3 pt border, its label scales up slightly, the other zones dim, and `.sensoryFeedback(.selection, trigger:)` gives a tick.
- **Tap hit-testing:** wrap the map in `MapReader`, convert the tap point with `proxy.convert(_:from: .local)`, and test it against each zone. Build one `CGPath` per zone in `MKMapPoint` space at load and use `contains(_:)`. Tapping a label selects its zone too.
- **Zoom and pan limits:** start with `MapCameraPosition.rect(norwayRect)` so MapKit fits mainland Norway (Svalbard left out) to the screen. Read that camera distance once and use it as `maximumDistance` in the map's `MapCameraBounds`, with a minimum of about 50 km.
- **Keeping the frame inside the box:** MapKit only bounds the camera *centre*. So in `onMapCameraChange(frequency: .onEnd)`, set `centerCoordinateBounds` to the Norway box inset by half the visible span. At full zoom-out the inset shrinks to a single point, so the frame is pinned exactly to the box; zoomed in, you can pan up to its edges but never past them.
- **Local avis panel:** under the map, the selected zone shows its regional avis and chips for the local ones, all on by default. Tap a chip to drop it. A "Bruk min posisjon i stedet" text button covers the position option.
- **Neste** is enabled once a zone is selected or position is chosen. It saves `regionId`, `paperIds` (regional plus the chosen local ones) and `startMode`, and the regional avis' city becomes the intro's `target` camera.

**Intro animations**

The intro is driven by cameras. A camera has four values: **centre** (the ground point it looks at), **distance** (how high up, in metres), **pitch** (0° looks straight down; higher gives the 3D view) and **heading** (which compass direction is up on screen). Setting a new camera moves the map, and animating that change makes it glide.

| Camera | Centre | Distance | Pitch | Used for |
| --- | --- | --- | --- | --- |
| `globe` | Over Norway (about 64° N, 12° E), whole Earth visible | about 60,000 km | 0° | Start of the first-launch intro |
| `europe` | Above the target | about 3,000 km | 0° | Start of the fast intro on later launches |
| `target` | Per user: current position or the local avis | about 3.5 km | 58° | Where every intro ends, and the start camera when the intro is off |

Heading is 0° (north up) on all three. `target` is computed, not hard-coded: a small `IntroCameras.target(settings:location:)` uses the current position when `startMode` is "my position" and permission is granted, otherwise the local avis, with Trondheim as the last fallback. Wait at most about 1 s for a location fix before computing it.

**First launch: two stacked maps, one smooth animation**

The globe can only be drawn with satellite imagery, so the first intro stacks two maps in a `ZStack`:

1. **Real map (underneath):** our `MKMapView`, already set to the `target` camera through the Coordinator, so the city tiles and 3D buildings load while the globe is showing.
2. **Globe map (on top):** a throwaway SwiftUI `Map` with `.mapStyle(.imagery(elevation: .realistic))`, no pins, and `.allowsHitTesting(false)`. It exists only for this intro.

The globe map then plays one continuous animation with two steps and no stop in between:

1. **Step 1, globe → Norway (about 2.5 s):** distance drops from 60,000 km to about 1,500 km, pitch stays 0°, and the centre starts drifting toward the target.
2. **Step 2, Norway → target (about 3 s):** distance drops to 3.5 km, the centre lands on the target, and pitch rises to 58° in the last second. Ease out at the end.
3. **Hand-off (about 0.4 s):** the globe map now shows exactly the `target` camera, the same as the real map underneath. Fade it out (opacity 1 → 0), remove it, and turn gestures on. The switch is invisible.

Build the two steps with `mapCameraKeyframeAnimator(trigger:)` on the globe map, with one `KeyframeTrack` per camera value (centre, distance, pitch, heading) and a middle keyframe at the Norway camera. Keyframes make both steps one continuous curve; two chained `withAnimation` calls would stop for a moment in between. Distance shrinks by a factor of about 17,000, so tune the timing curves until the speed feels even rather than slow-then-sudden.

**Later launches: one map, one camera move**

- No globe layer. The real map starts on the `europe` camera and glides to `target` in about 1.5 s, by wrapping the camera change in `UIView.animate(withDuration:)`.
- With "intro on every launch" off, the map starts directly on `target`.

**Both cases**

- Block map gestures during the intro, let a tap jump straight to `target`, and skip the animation entirely when Reduce Motion is on.
- The globe intro plays once, right after onboarding finishes. A "replay intro" switch in Settings is handy when rehearsing the demo.

**Map**

- **3D satellite:** `preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)` by default. Settings can switch to pure satellite (`MKImageryMapConfiguration`) or standard. 3D detail varies by city, so check Trondheim on a real device early.
- **Pins:** an `ItemAnnotationView` per kind, with category colour and icon. Read items get lower alpha, a smaller size, and `displayPriority = .defaultLow`, so MapKit hides them first when the map is crowded.
- **Clusters:** use MapKit's built-in clustering with `clusteringIdentifier`, which already animates merging and splitting. Register a custom `ClusterAnnotationView` for `MKMapViewDefaultClusterAnnotationViewReuseIdentifier` and draw the flare in it:
  - a count bubble,
  - up to 5 small category dots placed on an arc (for example −60° to +60°),
  - curved `UIBezierPath` lines connecting them, drawn once in `CAShapeLayer`s,
  - a scale-in animation in `prepareForDisplay()`.
- **Avoiding lag and twitching:**
  1. Never call `removeAnnotations(all)` followed by `addAnnotations(all)`. Diff by `id` in the Coordinator and only add or remove what changed.
  2. Reuse views with `dequeueReusableAnnotationView`.
  3. Debounce region changes to about 300 ms before fetching, cancel the previous request, and fetch a box 1.5× the visible area so small pans don't refetch.
  4. Keep the `MKMapView` out of SwiftUI's re-render path. The representable only pushes diffs, and read-state changes restyle existing views in place.
- **Zoom slider:**
  - A vertical slider on the right side, mapped logarithmically to camera distance, from about 1 km (your location) to about 5,500 km (all of Norway; far out the view glides to the middle of Norway): distance = 1 km × 5500^t for t from 0 to 1. A log scale makes the zoom feel even rather than jumpy.
  - The slider sets a target distance, and a `CADisplayLink` eases the camera toward it each frame. Smooth, but not too fast.
  - Use an `isUserDrivenChange` flag so pinch gestures update the slider without creating a feedback loop.
  - Set `cameraZoomRange` after the intro, so pinch stays inside the same range.
- **Layer and category toggles:** chips at the top for Saker, Arrangementer and Tilbud, plus a category menu. They update `FeedQuery`, which triggers a refetch.

**Item sheet**

- `.sheet` with `presentationDetents([.fraction(0.9)])`. Swiping down dismisses it and marks the item as read.
- Single pin: one card. Cluster: `TabView(.page)` with unread items first and a "2 / 5" position label at the top.
- `ItemSheetViewModel` tracks which pages were visited, and on dismiss calls `ReadStore.markRead(visited)`.
- Each kind gets its own card:
  - **Article:** image, title, 3-bullet summary, "Fra Adresseavisen", and a **"Les hele saken"** button that opens a `fullScreenCover`.
  - **Event:** time, place, "i kveld" badge.
  - **Ad/discount:** offer, valid until, distance.
- `ArticleReaderView` loads `GET /articles/:id` and shows each body paragraph in a `SelectableTextView`.

**Explain**

- `SelectableTextView` is a `UITextView` wrapper. It adds a **"Forklar"** action through `textView(_:editMenuForTextIn:suggestedActions:)`, both in the sheet summary and in the full article.
- `ExplainViewModel` calls `ExplainService`. The service reads `URLSession.bytes(for:)` line by line, parses the SSE, and yields deltas through an `AsyncThrowingStream`.
- The tooltip is a popover anchored to the selection (`attachmentAnchor: .rect(...)` + `.presentationCompactAdaptation(.popover)`), so it stays a small bubble on iPhone and grows as text streams in.
- The request sends the paragraph and title as context, so names get resolved correctly.
- Closing the tooltip cancels the task, which closes the HTTP stream and stops the Gemini call. No caching.

**List view**

- `ListViewModel` filters and sorts through the same `/feed` endpoint, with these chips:
  - **Nær meg:** CoreLocation distance (the default).
  - **I kveld:** events starting today after 16:00.
  - **Relevant:** the relevance score, based on matching categories.
  - **Sted:** pick a city or avis.
- Tapping an item opens the same sheet.

**Settings**

- Map style: 3D satellite, satellite with labels, or standard.
- Intro animation on every launch, on or off.
- Categories and blacklist, reusing the onboarding views.
- Region and local avis (the same zone map as onboarding), and start point.
- Reset read items, which is handy when rehearsing the demo.

**Style**

- VG-like structure: bold, tight headlines, card-based layout and fast scanning.
- Polaris flavour: avis logo and source badge on every card, a restrained palette with category accent colours, and dark mode support.

### 3.6 Design: Adresseavisen brand, VG-style iOS

Source: Adresseavisen's style guide on Frontify (Adressafargene, Adressaskriftene, Stil og tone, hierarki). The look is a newspaper made modern: VG-like structure (bold, tight headlines, cards, fast scanning) in Adresseavisen's colours and type. Tokens live in `DesignSystem/Theme.swift`; never hard-code a colour in a view.

**Colours (official hex)**

| Token | Hex | Source palette | Use in the app |
| --- | --- | --- | --- |
| `adressaBlue` | `#005379` | Hovedfarger: Adresseablå (PMS 7693 C) | Brand and primary: selected chips, buttons, kickers, the source badge, article pins |
| `cyan` | `#28aae2` | Hovedfarger: Cyan popup | Highlights and links on dark backgrounds, "i kveld" badge |
| `ink` | `#101010` | Hovedfarger: Svart | Headlines and body text (light mode) |
| `grey` | `#e2e2e2` | Hovedfarger: Grå | Dividers, unselected chip borders |
| `lightGrey` | `#f6f6f6` | Hovedfarger: Lys grå | Screen and sheet background (light mode) |
| `paperBlue` | `#e5edf5` | Redaksjonelle: Lyseblå papir | Fact boxes, "Kort fortalt" summary panel |
| `paperBeige` | `#dfded8` | Redaksjonelle: Beige papir | Quiet secondary panels |
| `kultur` | `#c31632` | Redaksjonelle: Kultur | Kultur category |
| `sport` | `#4e9d2d` | Redaksjonelle: Sport | Sport category |
| `korngul` | `#f7a800` | Kommersielle: Korngul | Ads / tilbud (commercial content), ad pins |
| `trdby` | `#ff9e18` | Trd.by: Pantone 1375C | Events (Trd.by is Adressa's "what's on" brand), event pins |

Layer colours: Saker = `adressaBlue`, Arrangementer = `trdby`, Tilbud = `korngul`. Dark mode swaps `ink`/`lightGrey` for near-black `#101010` backgrounds and white text; brand colours stay.

**Typography.** Adresseavisen uses Acta (titles and body, digital), Roboto (UI, commercial) and Stag Semibold (vignettes, product names). These are licensed, so the app maps them to iOS system fonts with the same roles:

| Brand font | Role | iOS stand-in |
| --- | --- | --- |
| Acta | Headlines and article body | New York (`.serif`): heavy for titles, regular for body |
| Stag Semibold | Vignettes / kickers ("KULTUR", "ARRANGEMENT") | SF Pro heavy, uppercase, small, tracked, in `adressaBlue` |
| Roboto Regular/Bold | UI: chips, buttons, meta lines | SF Pro regular/bold |

**Brand rules we follow**

- The logo is Adressablå (or white on Adressablå), never black. On small digital surfaces use the Adressasirkelen: a blue circle with a white A. We use it in the "Fra Adresseavisen" source badge.
- Commercial content is labelled "ANNONSE" so it is never confused with journalism. Every ad card shows it.
- Voice: talk *with* people, use "du/vi", few words, serious but light and modern. Say "Adresseavisen" in full when naming the brand; "adressa.no" with a lower-case a for the web.

**Components**

- *Map pins:* white card, serif title on top, photo below, pointer at the bottom; layer badge in the layer colour. Bunches: newest card on top, two smaller photo cards peeking out behind, count merged into the white frame.
- *Filter chips:* solid capsules. Selected = `adressaBlue` with white text; unselected = white with `ink` text and a soft shadow. One layer at a time.
- *Item sheet:* `lightGrey` background, standard iOS sheet corners. Kicker → serif headline → lead. Articles open in a short sheet (headline + lead) and expand to the full-height sheet with the photo, a "Kort fortalt" panel and "Les hele saken". Events and ads open in the full-height sheet directly. Bunches page left/right with an "n / total" counter; an article with several pins counts once.
- *Article reader:* full screen, edge-to-edge photo, serif headline and body, byline and date, the source badge, "Les saken på adressa.no", and a back button straight to the map.

### 3.7 Two-day plan

Assumes 4–5 people. The app team starts on `MockFeedService` with bundled JSON, so nobody waits for the backend.

| When | Backend | Map | Sheet + Explain | Onboarding, List, Settings | Pitch |
| --- | --- | --- | --- | --- | --- |
| Day 1 morning | `SharedModels`, Vapor skeleton, JSON and GeoJSON files, `/feed`, `/categories`, `/papers` | Tab bar, 3D `MKMapView`, basic pins | Sheet with an article card | Stores, onboarding UI and region map | Talk to fellow students, write the problem statement |
| Day 1 afternoon | Filters and sorting, `/articles/:id` | Clustering, diffing, debounce, zoom slider | Paged cluster sheet, full article | List view and chips | Demo storyline |
| Day 1 evening | `POST /explain` with SSE | Flare cluster view, read-state styling | `SelectableTextView` and streaming tooltip | Settings | Slides for points 1, 4 and 5 |
| Day 2 morning | Polish mock data (tonight's events, deals near campus), deploy | Intro animations | Event and deal cards | Polish and dark mode | Rehearse |

Feature freeze at lunch on day 2. After that: bug fixes only, rehearse on a real iPhone, and record a backup video of the demo.

## 4. Diagrams

Six diagrams: architecture, classes, user flow, two sequences and the API. Each has one line on how to read it; the API section also has the full endpoint reference.

### 4.1 Architecture

&#91;embedded content: architecture · iOS app, Vapor backend, Gemini\]

Arrows point from caller to callee: views bind to viewmodels, viewmodels use injected services and stores, and only APIClient talks to the backend. Both sides import the same SharedModels DTOs, so the API contract can't drift.

### 4.2 Class diagram (minimum to get running)

&#91;embedded content: class diagram · models, services and stores, viewmodels, map layer\]

Read the columns right to left: ViewModels use injected services and stores, and services return value-type models. The map layer is the UIKit part: the Coordinator diffs annotations and tells MapViewModel about region changes and taps.

### 4.3 User flow

&#91;embedded content: user flow · launch, tab bar, map, list, settings, sheet\]

Only the first launch goes through onboarding and the slow globe zoom. After that, the map and the list both open the same item sheet, and Forklar works in the sheet and in the full article.

### 4.4 Sequence: Forklar (explain)

&#91;embedded content: sequence · Forklar, streamed explanation and cancel\]

Solid arrows are calls, dashed arrows are data coming back. The tooltip grows with every chunk, and closing it early cancels the task, which closes the connection and stops the Gemini request.

### 4.5 Sequence: show pins and open an item

&#91;embedded content: sequence · load pins, tap, read, mark as read\]

The card renders from the feed item already in memory, so only Les hele saken costs a request. Read state stays on the phone: ReadStore changes, MapViewModel observes it, and the Coordinator fades those pins in place instead of re-adding them.

### 4.6 API design

&#91;embedded content: API map · callers, endpoints, backend sources\]

Map and list share one endpoint with different query params, and every read endpoint is served from the same in-memory repository. Only POST /explain leaves our server.

Base path `/api/v1`. All responses are JSON except `/explain`, which streams Server-Sent Events.

| Method | Path | Input | Response |
| --- | --- | --- | --- |
| GET | `/feed` | Query params, see below | `200 FeedPage` |
| GET | `/articles/:id` | Path id | `200 ArticleDetail`, `404` if unknown |
| GET | `/categories` | None | `200 [Category]` |
| GET | `/papers` | None | `200 [Paper]`, each with `regionId` and `level` |
| GET | `/regions` | None | `200` GeoJSON `FeatureCollection` (`application/geo+json`) |
| POST | `/explain` | `ExplainRequest` body | `200 text/event-stream`; `400` bad input, `502` Gemini down |
| GET | `/health` | None | `200 ok` |

**`/feed` query parameters** (all optional, comma-separated lists)

| Param | Example | Meaning |
| --- | --- | --- |
| `kinds` | `article,event,ad` | Which layers; default all |
| `categories` | `kultur,sport` | Only these categories (map filter chips) |
| `exclude` | `krim` | Blacklisted categories |
| `mute` | `valg,rbk` | Blacklisted words, matched in title and tags |
| `bbox` | `63.40,10.35,63.45,10.45` | minLat,minLon,maxLat,maxLon (map) |
| `near` + `radiusKm` | `63.42,10.40` + `5` | Centre and radius (list); also fills `distanceKm` |
| `paper` | `adressa` | Only one avis (list "Sted") |
| `when` | `tonight`, `today`, `week` | Time window; `tonight` = events today after 16:00 |
| `sort` | `time`, `distance`, `relevance` | Default `time`; `distance` needs `near` |
| `prefer` | `kultur,studentliv` | The user's categories, used by `relevance` |
| `limit` | `200` | Default 200, max 500 |

**`FeedPage`**: one item shape for all kinds. `kind` decides what `details` holds, and in Swift `FeedItem.Details` is an enum with a custom `init(from:)` that reads `kind` first.

```json
{
  "items": [
    {
      "id": "evt_017",
      "kind": "event",
      "title": "Quiz på Samfundet",
      "categoryId": "studentliv",
      "paperId": "adressa",
      "location": { "lat": 63.4224, "lon": 10.3950, "name": "Studentersamfundet" },
      "imageUrl": "https://example.com/quiz.jpg",
      "date": "2026-10-16T19:00:00+02:00",
      "distanceKm": 1.2,
      "details": {
        "startsAt": "2026-10-16T19:00:00+02:00",
        "endsAt": "2026-10-16T22:00:00+02:00",
        "venue": "Klubben",
        "price": "Gratis for medlemmer"
      }
    }
  ],
  "total": 134
}
```

| `kind` | `details` fields |
| --- | --- |
| `article` | `summary` (3 strings), `readMinutes` |
| `event` | `startsAt`, `endsAt`, `venue`, `price` |
| `ad` | `merchant`, `offer`, `validUntil` |

**`ArticleDetail`, `Category`, `Paper`**

```json
{ "id": "art_1042", "title": "…", "lead": "…", "body": ["Avsnitt 1", "Avsnitt 2"],
  "author": "…", "publishedAt": "2026-10-14T08:30:00+02:00", "paperId": "adressa",
  "sourceUrl": "https://www.adressa.no/…" }

{ "id": "kultur", "name": "Kultur", "symbol": "theatermasks", "color": "#8E44AD" }

{ "id": "adressa", "name": "Adresseavisen", "city": "Trondheim",
  "location": { "lat": 63.4305, "lon": 10.3951 }, "logoUrl": "https://…",
  "color": "#1F4E79", "regionId": "trondelag", "level": "regional" }
```

**`GET /regions`**: one GeoJSON feature per zone (outline shortened below). The backend fills `localPaperIds` from `papers.json` when it loads, so there is one source of truth. The app decodes the response with `MKGeoJSONDecoder`, which returns `MKMultiPolygon` shapes plus each feature's `properties` as JSON data.

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "id": "trondelag",
        "name": "Trøndelag",
        "color": "#1F4E79",
        "regionalPaperId": "adressa",
        "localPaperIds": ["fosna-folket", "hitra-froya", "innherred"],
        "labelPoint": { "lat": 63.6, "lon": 10.9 }
      },
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [[[[10.39, 63.43], [10.41, 63.44], [10.40, 63.45], [10.39, 63.43]]]]
      }
    }
  ]
}
```

**`POST /explain`**: request body, then the streamed response.

```json
{
  "term": "formannskapet",
  "context": "The paragraph the word was selected in.",
  "title": "The article title",
  "itemId": "art_1042"
}
```

```text
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache

data: {"delta":"Formannskapet er "}

data: {"delta":"et politisk utvalg i kommunen som …"}

event: done
data: {}
```

**Errors.** Before the stream starts, the backend returns Vapor's standard error body, `{"error": true, "reason": "term must be 1–80 characters"}`, with `400` or `502`. If Gemini fails mid-stream, it sends `event: error` with `data: {"reason": "…"}`, and the tooltip shows a retry button.

## 5. Future work

These are ideas we would build next; none of them are part of the 2-day prototype.

- **Too much happening → more summaries.** A daily "this happened near you today" digest, and one merged summary when several articles cover the same story.
- **Unimportant stories drown the important ones.** Some stories get a lot of coverage while important ones get buried. Editorial weight from journalists, plus merging duplicates into one pin, keeps big-but-minor stories from crowding the map.
- **Choose what notifies you.** Settings per category, radius and time window, plus a daily cap, because too many notifications are the fastest way to get muted.
- **Interactive notifications on iOS.** Actionable buttons such as "Forklar", "Vis på kartet", "Lagre" and "Ikke interessert"; rich previews with a small map through a Notification Content Extension; and a Live Activity for an event you saved for tonight.
- **Retention without being annoying.** Send the best few notifications, not the most: a "tonight" nudge in the afternoon, quiet hours, a per-user budget, and learning from what gets opened or dismissed.
- **Real data.** A Polaris API instead of mock JSON, with journalists adding a location when they publish.
- **Accounts and sync.** Read state and settings across devices, and Android and web later.

## 6. The app in short

Our app is a map-first news app for students. You choose what you want to see and hide what you don't, and the app starts at your local avis or your own position.

Every article, event and deal is a pin on a 3D map. Tap a pin for a short summary you can read in seconds, or tap a cluster to swipe through everything happening in that spot. Anything you don't understand, a name, a place or a term, you select and get explained instantly.

For students it answers "what's happening around me, and tonight?" For Polaris it puts local journalism in front of young readers through a daily habit, built on content only a local newsroom has.x

