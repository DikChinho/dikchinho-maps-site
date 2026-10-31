# DikChinho Navigation — Architecture v1

## Product direction

**DikChinho is a Bangladesh-first navigation platform.** It should help people select a suitable route for their vehicle, understand the next manoeuvre, and receive useful local road information. It is not intended to reproduce every feature of Google Maps.

Initial geographic scope: Savar, then wider Dhaka. Do not treat map coverage as verified merely because a road appears in OpenStreetMap.

## Current application boundary

The public GitHub Pages website is a static front end. Its current capabilities are:

| Area | Current implementation | Limitation |
|---|---|---|
| Map | Leaflet with an OpenFreeMap/MapLibre vector style when available; OSM raster fallback; Esri imagery toggle | Third-party hosting; no SLA; no offline map downloads |
| Search | Photon + Nominatim | Search results depend on external indexes and their use policies |
| Routing | Valhalla public demo API, OSRM-compatible response format | Fair-use demo only; not our own routing infrastructure |
| Vehicle profiles | Valhalla `auto`, `motorcycle`, `motor_scooter`, `bicycle`, `pedestrian` | Motorcycle costing is marked beta upstream; source map access tags need local QA |
| Route preferences | Balanced, shortest, avoid tolls, avoid highways | These are routing-engine preferences, not guaranteed road conditions |
| Navigation | Browser GPS watch, spoken instruction, reroute when sufficiently off route | Browser background/locked-screen behaviour varies by device |
| Road reports | Browser localStorage prototype | Visible only on the same browser/device; not shared |
| Shared data | SQL foundation prepared in `supabase/schema.sql` | Not connected; no Supabase project credentials or auth integration yet |

## Target architecture

### 1. Client

- PWA web client for early testing.
- MapLibre-compatible vector map renderer and an independently configurable tile provider.
- Route planning adapter with a stable internal route format so providers can be changed without rewriting the UI.
- GPS state machine: permission, acquiring, tracking, stale location, off-route, rerouting and arrival.
- Local cache for user preferences and explicitly device-local drafts.
- Native Android application in a later phase for dependable foreground-service navigation, screen-off behaviour and better battery/GPS control.

### 2. Search

- Fast typeahead with a local search cache.
- A place index with English, Bangla and common transliteration aliases.
- Distinguish a building's name from its entrance and the road-side access point.
- Future search API should use the local place index first, then fall back to external geocoders.

### 3. Routing

Valhalla is the chosen routing-engine candidate because its costing models include auto, motorcycle, motor scooter, bicycle and pedestrian. Its API supports dynamic costing options, route alternatives and OSRM-compatible output. The prototype currently calls the public FOSSGIS demo endpoint only.

Production routing plan:
1. Provision a small Linux server or managed deployment environment.
2. Build a Valhalla graph from a Bangladesh OSM extract.
3. Initially serve only Savar/Dhaka extracts where possible to control infrastructure cost.
4. Tune costing and access rules using verified local road observations.
5. Add operational monitoring, rate limits, health checks and scheduled OSM graph updates.
6. Do not use the public demo server as a production dependency.

The app's route adapter must remain provider-independent. A self-hosted endpoint should be configurable without changing the navigation UI.

### 4. Road intelligence

The road graph is not enough by itself. Add local attributes with provenance and verification:

- vehicle access and restrictions
- road class and width
- surface and condition
- one-way and turn restrictions
- known entrance/access point
- temporary closure and construction
- waterlogging, crash, congestion and hazard reports
- source, verification status, observed time and expiry

Separate permanent road attributes from temporary events. Temporary reports must expire and must not silently become permanent map facts.

### 5. Data platform

Use a **new, dedicated Supabase project for DikChinho**, with PostgreSQL and PostGIS. Never reuse the user's CER Tracker database. Enable Row Level Security and keep privileged keys on the server only.

The prepared schema includes:
- `road_segments`: locally verified road-segment overrides and OSM references
- `place_names`: place points, Bangla/English names and aliases
- `road_reports`: time-bounded community incident reports
- `road_report_votes`: authenticated confirmations

The SQL is a foundation, not a complete live backend. Before enabling public submissions add Supabase Auth, server-side rate limiting, abuse prevention, moderation, report expiry jobs and a privacy policy.

### 6. Traffic

Do not label the prototype as having live traffic. A future traffic estimate can be built from:
- opt-in, minimised GPS travel observations
- map-matched road segments
- time-of-day historical speed baselines
- user-submitted events with confidence and expiry
- official or partner feeds where licensing permits

Aggregate observations; do not retain identifiable trip histories unnecessarily. Display freshness and confidence. Never imply an unverified report is confirmed.

## Data quality rules

1. Every non-OSM correction records its source, author and verification date.
2. Road access restrictions require evidence; do not infer them from road width or appearance alone.
3. Vehicle suitability is distinct from legal access.
4. Building centroids are not navigation entrances.
5. Every temporary incident has an expiry and a status.
6. A route can only be called “best”, “safe” or “fastest” relative to explicit criteria and available data.

## Rollout gates

### Phase 1 — Savar navigation MVP
- Vehicle-aware route calculation
- Start/destination search and map selection
- GPS tracking, turn instructions and rerouting
- Local report workflow for usability testing
- Test with real drivers on known journeys

### Phase 2 — Shared road intelligence
- Dedicated Supabase project
- Authenticated reports and confirmations
- Moderation and automatic expiry
- Local road/place correction dashboard

### Phase 3 — Own routing and map services
- Self-hosted Valhalla and graph updates
- Own vector tile hosting or contracted provider
- Local search index
- Route-quality monitoring

### Phase 4 — Production mobile navigation
- Android foreground navigation service
- Offline map packages from a provider or self-hosted tiles that explicitly permit downloads
- Battery/GPS optimisation
- crash/error reporting with privacy controls

### Phase 5 — Dhaka and Bangladesh expansion
- Expand only after local route-quality gates pass.
- Measure search success, route completion, wrong turns, unsuitable-road reports, ETA error and reroute delay.

## Current known gaps

- Road reports are local-only and are not shared.
- There is no live traffic source.
- No local road dataset has yet been independently verified or loaded.
- No offline map package is available.
- The public Valhalla demo, external search providers and map providers are temporary dependencies.
- The PWA shell can be cached, but map tiles and route/search APIs still need network access.
- Full background navigation should move to a native app rather than relying on browser behaviour.
